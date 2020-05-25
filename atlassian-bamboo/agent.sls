{%- from 'atlassian-bamboo/map.jinja' import bamboo with context %}

include:
  - java

bamboo-agent:
  file.managed:
    - name: /etc/systemd/system/atlassian-bamboo-agent@.service
    - source: salt://atlassian-bamboo/files/atlassian-bamboo-agent.service
    - template: jinja
    - defaults:
        config: {{ bamboo.agent|json }}

  module.wait:
    - name: service.systemctl_reload
    - watch:
      - file: bamboo-agent

  group.present:
    - name: {{ bamboo.agent.group }}

  user.present:
    - name: {{ bamboo.agent.user }}
    - gid: {{ bamboo.agent.group }}
    - home: {{ bamboo.agent.home }}
    - require:
      - group: bamboo-agent
      - file: bamboo-agent-dir

{% for agent in bamboo.agent.get('agents', []) %}
bamboo-agent-{{ agent }}:
  service.running:
    - name: atlassian-bamboo-agent@{{ agent }}
    - enable: True
    - watch:
      - file: bamboo-agent
      - file: bamboo-agent-run-sh
      - file: bamboo-agent-capabilities
    - require:
      - cmd: bamboo-agent-install-{{ agent }}
      - file: bamboo-agent-capabilities-{{ agent }}

bamboo-agent-install-{{ agent }}:
  cmd.run:
    - name: "{{ bamboo.agent.java_home }}/bin/java -Dbamboo.home={{ bamboo.agent.home }}/{{ agent }} -jar {{ bamboo.agent.installer_jar }} {{ bamboo.agent.server_url }}/agentServer/ {{ '-t ' + bamboo.agent.security_token if bamboo.agent.get('security_token') else '' }} install"
    - unless: 'test -f {{ bamboo.agent.home }}/{{ agent }}/bin/bamboo-agent.sh'
    - runas: {{ bamboo.agent.user }}
    - require:
      - cmd: bamboo-agent-installer
      - file: bamboo-agent-home

bamboo-agent-capabilities-{{ agent }}:
  file.symlink:
    - name: {{ bamboo.agent.home }}/{{ agent }}/bin/bamboo-capabilities.properties
    - target: {{ bamboo.agent.dir }}/bamboo-capabilities.properties
    - makedirs: True
    - user: {{ bamboo.agent.user }}
    - group: {{ bamboo.agent.group }}
    - require:
      - cmd: bamboo-agent-install-{{ agent }}
      - file: bamboo-agent-capabilities
{% endfor %}

bamboo-agent-installer:
  cmd.run:
    - name: 'curl "{{ bamboo.agent.url }}" --silent -o "{{ bamboo.agent.installer_jar }}"'
    - unless: 'test -f "{{ bamboo.agent.installer_jar }}"'
    - cwd: {{ bamboo.agent.dir }}
    - require:
      - file: bamboo-agent-dir

bamboo-agent-dir:
  file.directory:
    - name: {{ bamboo.agent.dir }}
    - mode: 755
    - user: root
    - group: root
    - makedirs: True

bamboo-agent-home:
  file.directory:
    - name: {{ bamboo.agent.home }}
    - user: {{ bamboo.agent.user }}
    - group: {{ bamboo.agent.group }}
    - mode: 755
    - require:
      - file: bamboo-agent-dir
    - makedirs: True

bamboo-agent-run-sh:
  file.managed:
    - name: {{ bamboo.agent.dir }}/run-agent.sh
    - mode: 755
    - require:
      - file: bamboo-agent-dir
    - contents: |
        #!/bin/sh
        export JAVA_HOME={{ bamboo.agent.java_home }}
        {{ bamboo.agent.home }}/$1/bin/bamboo-agent.sh $2

{%- macro capability(content = {}, prefix = [], seperator = '.') %}
{%- for key, val in content.items()  %}
{%- set newPrefix = prefix[:] %}
{%- do newPrefix.append(key) %}
{%- if val is string %}
{{ newPrefix|join(seperator)|replace('\\', '\\\\')|replace(' ', '\ ') }}={{ val }}
{%- else -%}
{{ capability(val, newPrefix) }}
{%- endif %}
{%- endfor %}
{%- endmacro %}

bamboo-agent-capabilities:
  file.managed:
    - name: {{ bamboo.agent.dir }}/bamboo-capabilities.properties
    - user: root
    - group: root
    - require:
      - file: bamboo-agent-dir
    - contents: |
        # Capabilities managed by salt
        {{ capability(bamboo.agent.get('capabilities', {}))|indent(8) }}

