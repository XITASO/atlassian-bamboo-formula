{%- from 'atlassian-bamboo/map.jinja' import bamboo with context %}

include:
  - java

bamboo-agent:
  file.managed:
    - name: /etc/systemd/system/atlassian-bamboo-agent.service
    - source: salt://atlassian-bamboo/files/atlassian-bamboo-agent.service
    - template: jinja
    - defaults:
        config: {{ bamboo.agent }}

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
    - createhome: True
    - require:
      - group: bamboo-agent
      - file: bamboo-agent-dir

  service.running:
    - name: atlassian-bamboo-agent
    - enable: True
    - require:
      - file: bamboo-agent
    - watch:
      - file: bamboo-agent-capabilities

bamboo-agent-graceful-down:
  service.dead:
    - name: atlassian-bamboo-agent
    - require:
      - module: bamboo-agent
    - prereq:
      - file: bamboo-agent-install

bamboo-agent-install:
  cmd.run:
    - name: curl "{{ bamboo.agent.url }}" --silent -o "{{ bamboo.agent.current_jar }}"
    - unless: test -f "{{ bamboo.agent.current_jar }}"
    - cwd: {{ bamboo.agent.dir }}
    - require:
      - file: bamboo-agent-dir

  file.symlink:
    - name: {{ bamboo.agent.jar }}
    - target: {{ bamboo.agent.current_jar }}
    - require:
      - cmd: bamboo-agent-install
    - watch_in:
      - service: bamboo-agent

bamboo-agent-dir:
  file.directory:
    - name: {{ bamboo.agent.dir }}
    - mode: 755
    - user: root
    - group: root
    - makedirs: True

{%- macro capability(content = {}, prefix = [], seperator = '.') %}
{%- for key, val in content.iteritems()  %}
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
    - name: {{ bamboo.agent.home }}/bamboo-agent-home/bin/bamboo-capabilities.properties
    - user: {{ bamboo.agent.user }}
    - group: {{ bamboo.agent.group }}
    - makedirs: True
    - contents: |
        # Capabilities managed by salt
        {{ capability(bamboo.agent.get('capabilities', {}))|indent(8) }}
