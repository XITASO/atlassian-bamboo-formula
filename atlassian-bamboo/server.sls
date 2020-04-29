{%- from 'atlassian-bamboo/map.jinja' import bamboo with context %}

include:
  - java

bamboo-dependencies:
  pkg.installed:
    - pkgs:
      - libxslt

bamboo:
  file.managed:
    - name: /etc/systemd/system/atlassian-bamboo.service
    - source: salt://atlassian-bamboo/files/atlassian-bamboo.service
    - template: jinja
    - defaults:
        config: {{ bamboo.server|json }}

  module.wait:
    - name: service.systemctl_reload
    - watch:
      - file: bamboo

  group.present:
    - name: {{ bamboo.server.group }}

  user.present:
    - name: {{ bamboo.server.user }}
    - gid: {{ bamboo.server.group }}
    - home: {{ bamboo.server.dirs.home }}
    - require:
      - group: bamboo
      - file: bamboo-dir

  service.running:
    - name: atlassian-bamboo
    - enable: True
    - require:
      - file: bamboo

bamboo-graceful-down:
  service.dead:
    - name: atlassian-bamboo
    - require:
      - module: bamboo
    - prereq:
      - file: bamboo-install

bamboo-install:
  archive.extracted:
    - name: {{ bamboo.server.dirs.extract }}
    - source: {{ bamboo.server.url }}
    - if_missing: {{ bamboo.server.dirs.current_install }}
    - skip_verify: True
    - options: z
    - keep: True
    - require:
      - file: bamboo-extractdir

  file.symlink:
    - name: {{ bamboo.server.dirs.install }}
    - target: {{ bamboo.server.dirs.current_install }}
    - require:
      - archive: bamboo-install
    - watch_in:
      - service: bamboo

bamboo-server-xsl:
  file.managed:
    - name: {{ bamboo.server.dirs.temp }}/server.xsl
    - source: salt://atlassian-bamboo/files/server.xsl
    - template: jinja
    - require:
      - file: bamboo-install

  cmd.run:
    - name: 'xsltproc --stringparam pHttpPort "{{ bamboo.server.get('http_port', '') }}" --stringparam pHttpScheme "{{ bamboo.server.get('http_scheme', '') }}" --stringparam pHttpProxyName "{{ bamboo.server.get('http_proxyName', '') }}" --stringparam pHttpProxyPort "{{ bamboo.server.get('http_proxyPort', '') }}" --stringparam pAjpPort "{{ bamboo.server.get('ajp_port', '') }}" -o "{{ bamboo.server.dirs.temp }}/server.xml" "{{ bamboo.server.dirs.temp }}/server.xsl" server.xml'
    - cwd: {{ bamboo.server.dirs.install }}/conf
    - require:
      - file: bamboo-server-xsl
      - file: bamboo-tempdir

bamboo-server-xml:
  file.managed:
    - name: {{ bamboo.server.dirs.install }}/conf/server.xml
    - source: {{ bamboo.server.dirs.temp }}/server.xml
    - require:
      - cmd: bamboo-server-xsl
    - watch_in:
      - service: bamboo

bamboo-dir:
  file.directory:
    - name: {{ bamboo.server.dir }}
    - mode: 755
    - user: root
    - group: root
    - makedirs: True

bamboo-scriptdir:
  file.directory:
    - name: {{ bamboo.server.dirs.scripts }}
    - use:
      - file: bamboo-dir

bamboo-tempdir:
  file.directory:
  - name: {{ bamboo.server.dirs.temp }}
  - use:
    - file: bamboo-dir

bamboo-home:
  file.directory:
    - name: {{ bamboo.server.dirs.home }}
    - user: {{ bamboo.server.user }}
    - group: {{ bamboo.server.group }}
    - require:
      - user: bamboo
      - group: bamboo
    - use:
      - file: bamboo-dir

bamboo-home-configuration:
  file.directory:
    - name: {{ bamboo.server.dirs.home }}/xml-data/configuration
    - makedirs: True
    - use:
      - file: bamboo-home
    - require:
      - file: bamboo-home

bamboo-extractdir:
  file.directory:
    - name: {{ bamboo.server.dirs.extract }}
    - use:
      - file: bamboo-dir

{% for file in [ 'env.sh', 'start.sh', 'stop.sh' ] %}
bamboo-script-{{ file }}:
  file.managed:
    - name: {{ bamboo.server.dirs.scripts }}/{{ file }}
    - source: salt://atlassian-bamboo/files/{{ file }}
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - defaults:
        config: {{ bamboo.server|json }}
    - require:
      - file: bamboo-scriptdir
    - watch_in:
      - service: bamboo
{% endfor %}

{% if bamboo.server.get('crowd') %}
bamboo-crowd-properties:
  file.managed:
    - name: {{ bamboo.server.dirs.home }}/xml-data/configuration/crowd.properties
    - user: {{ bamboo.server.user }}
    - group: {{ bamboo.server.group }}
    - makedirs: True
    - require:
      - file: bamboo-home

{% for key, val in bamboo.server.crowd.items() %}
bamboo-crowd-{{ key }}:
  file.replace:
    - name: {{ bamboo.server.dirs.home }}/xml-data/configuration/crowd.properties
    - pattern: ^#?\s*{{ key|replace(".", "\\.") }}[\s=].*
    - repl: "{{ key }} = {{ val|replace(":", "\\\\:") }}"
    - count: 1
    - append_if_not_found: True
    - require:
      - file: bamboo-crowd-properties
    - watch_in:
      - service: bamboo
{% endfor %}
{% endif %}

bamboo-atlassian-user:
  file.managed:
    - name: {{ bamboo.server.dirs.home }}/xml-data/configuration/atlassian-user.xml
    - source: salt://atlassian-bamboo/files/atlassian-user.xml
    - template: jinja
    - user: {{ bamboo.server.user }}
    - group: {{ bamboo.server.group }}
    - defaults:
        config: {{ bamboo.server|json }}
    - require:
      - file: bamboo-home
      - file: bamboo-home-configuration
    - watch_in:
      - service: bamboo

{#
bamboo-dbconfig:
  file.managed:
    - name: {{ bamboo.server.dirs.home }}/dbconfig.xml
    - source: salt://atlassian-bamboo/files/dbconfig.xml
    - template: jinja
    - defaults:
        dbconfig: {{ bamboo.server.get('dbconfig', {})|json }}
    - require:
      - file: bamboo-home
    - watch_in:
      - service: bamboo
#}

{% for chmoddir in ['bin', 'work', 'temp', 'logs'] %}
bamboo-permission-{{ chmoddir }}:
  file.directory:
    - name: {{ bamboo.server.dirs.install }}/{{ chmoddir }}
    - user: {{ bamboo.server.user }}
    - group: {{ bamboo.server.group }}
    - recurse:
      - user
      - group
    - require:
      - file: bamboo-install
    - require_in:
      - service: bamboo
{% endfor %}

bamboo-disable-BambooAuthenticator:
  file.replace:
    - name: {{ bamboo.server.dirs.install }}/atlassian-bamboo/WEB-INF/classes/seraph-config.xml
    - pattern: |
        ^(\s*)[\s<!-]*(<authenticator class="com\.atlassian\.bamboo\.user\.authentication\.BambooAuthenticator"\/>)[\s>-]*$
    - repl: |
        {% if bamboo.server.crowdSSO %}\1<!-- \2 -->{% else %}\1\2{% endif %}
    - watch_in:
      - service: bamboo

bamboo-enable-CrowdBambooAuthenticator:
  file.replace:
    - name: {{ bamboo.server.dirs.install }}/atlassian-bamboo/WEB-INF/classes/seraph-config.xml
    - pattern: |
        ^(\s*)[\s<!-]*(<authenticator class="com\.atlassian\.crowd\.integration\.seraph\.v25\.BambooAuthenticator"\/>)[\s>-]*$
    - repl: |
        {% if bamboo.server.crowdSSO %}\1\2{% else %}\1<!-- \2 -->{% endif %}
    - watch_in:
      - service: bamboo

