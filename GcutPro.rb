# Código Mestre FINAL e Corrigido para: GcutPro/GcutPro.rb

require 'sketchup.rb'
require 'json'

module GcutPro # <--- Módulo Renomeado
  module Core

    ATRIBUTOS_DESEJADOS = {
      "lenx" => "Largura",
      "leny" => "Profundidade",
      "lenz" => "Altura",
    }
    
    def self.get_local_components
      plugin_root_dir = __dir__; components_dir = File.join(plugin_root_dir, 'componentes_originais'); thumbnails_dir = File.join(plugin_root_dir, 'thumbnails'); categories_data = {}; Dir.mkdir(thumbnails_dir) unless Dir.exist?(thumbnails_dir); unless Dir.exist?(components_dir); UI.messagebox("Pasta 'componentes_originais' não encontrada."); return {}; end; Dir.glob(File.join(components_dir, '**', '*.skp')).each do |skp_path|; begin; relative_path = skp_path.sub(components_dir + '/', ''); path_parts = relative_path.split('/'); next unless path_parts.length > 2; category_name = path_parts[0]; subcategory_name = path_parts[1]; definition_name = File.basename(skp_path, '.skp'); thumbnail_path = File.join(thumbnails_dir, "#{definition_name}.png"); unless File.exist?(thumbnail_path); definition = Sketchup.active_model.definitions.load(skp_path); definition.save_thumbnail(thumbnail_path) if definition; end; categories_data[category_name] ||= {}; categories_data[category_name][subcategory_name] ||= []; categories_data[category_name][subcategory_name].push({name: definition_name, skp_path: skp_path, thumbnail_path: thumbnail_path}); rescue => e; puts "Erro ao processar o componente: #{skp_path} | Erro: #{e.message}"; end; end; return categories_data;
    end

    def self.mostrar_galeria
      dialog = UI::HtmlDialog.new({dialog_title: "Galeria de Componentes GcutPro", width: 800, height: 700, style: UI::HtmlDialog::STYLE_DIALOG, resizable: true}); dialog.add_action_callback("on_dialog_ready") do |_action_context|; components_map = self.get_local_components; json_data = JSON.generate(components_map); js_command = "initializeGallery(#{json_data});"; dialog.execute_script(js_command); end; dialog.add_action_callback("insert_component") do |_action_context, skp_path|; model = Sketchup.active_model; definitions = model.definitions; begin; component_definition = definitions.load(skp_path); if component_definition.nil? || component_definition.attribute_dictionary("dynamic_attributes").nil?; UI.messagebox("O componente '#{File.basename(skp_path)}' não parece ser um Componente Dinâmico válido ou o arquivo pode estar corrompido.\n\nTente salvá-lo novamente usando o método 'Botão Direito > Salvar como...'."); next; end; DCHelper.make_definition_dynamic(component_definition) if defined?(DCHelper); model.place_component(component_definition, true) if component_definition; rescue => e; UI.messagebox("Falha ao carregar o componente: #{e.message}"); end; end; html_file = File.join(__dir__, 'html', 'galeria_dialog.html'); dialog.set_file(html_file); dialog.show;
    end
    
    def self.abrir_editor
      selection = Sketchup.active_model.selection
      if selection.empty? || selection.length > 1 || !selection.first.is_a?(Sketchup::ComponentInstance)
        UI.messagebox("Por favor, selecione apenas um componente.")
        return
      end
      
      componente_selecionado = selection.first
      atributos_dinamicos = componente_selecionado.attribute_dictionary("dynamic_attributes")
      
      if atributos_dinamicos.nil?
        UI.messagebox("O componente selecionado não é um Componente Dinâmico.")
        return
      end
      
      atributos_para_editar = []
      ATRIBUTOS_DESEJADOS.each_pair do |nome_sistema, nome_amigavel|
        if valor_em_polegadas = atributos_dinamicos[nome_sistema]
          valor_para_exibir = Sketchup.format_length(valor_em_polegadas.to_f).to_f
          atributos_para_editar.push({system_name: nome_sistema, friendly_name: nome_amigavel, value: valor_para_exibir})
        end
      end

      editor_dialog = UI::HtmlDialog.new({dialog_title: "Editor de Atributos GcutPro", width: 400, height: 500, style: UI::HtmlDialog::STYLE_DIALOG}) # <--- Título da Janela Renomeado
      editor_dialog.add_action_callback("on_editor_ready") do |_action_context|; json_data = JSON.generate(atributos_para_editar); js_command = "initializeEditor(#{json_data});"; editor_dialog.execute_script(js_command); end
      
      editor_dialog.add_action_callback("apply_changes") do |_action_context, novos_atributos|
        dicionario = componente_selecionado.attribute_dictionary("dynamic_attributes")
        
        novos_atributos.each_pair do |key, value|
          valor_em_polegadas = value.to_l
          dicionario[key] = valor_em_polegadas
        end
        
        tr = Geom::Transformation.new
        componente_selecionado.transform!(tr)
        
        editor_dialog.close
      end

      editor_html_file = File.join(__dir__, 'html', 'editor_dialog.html')
      editor_dialog.set_file(editor_html_file)
      editor_dialog.show
    end

    unless file_loaded?(__FILE__)
      menu = UI.menu('Extensions')
      menu.add_item('Abrir Galeria GcutPro') { self.mostrar_galeria } # <--- Item de Menu Renomeado

      toolbar = UI::Toolbar.new "GcutPro Ferramentas" # <--- Barra de Ferramentas Renomeada
      
      # Ferramenta da Galeria
      cmd_galeria = UI::Command.new("Abrir Galeria") { self.mostrar_galeria } # <--- Comando Renomeado
      icon_galeria_path = File.join(__dir__, 'galeria_icon.png') # <--- Novo Ícone para a Galeria
      cmd_galeria.small_icon = icon_galeria_path
      cmd_galeria.large_icon = icon_galeria_path
      cmd_galeria.tooltip = "Abrir Galeria de Componentes GcutPro"
      cmd_galeria.status_bar_text = "Navegue e insira componentes dinâmicos da Galeria GcutPro."
      toolbar.add_item cmd_galeria

      # Ferramenta do Editor (Lápis)
      cmd_editor = UI::Command.new("Editar Componente") { self.abrir_editor }
      icon_editor_path = File.join(__dir__, 'editor_icon.png') # <--- Ícone do Lápis
      cmd_editor.small_icon = icon_editor_path
      cmd_editor.large_icon = icon_editor_path
      cmd_editor.tooltip = "Editar Atributos do Componente Dinâmico Selecionado"
      cmd_editor.status_bar_text = "Selecione um componente e clique para editar suas propriedades."
      toolbar.add_item cmd_galeria
      toolbar.add_separator # <--- ADICIONE ESTA LINHA AQUI
      toolbar.add_item cmd_editor

      toolbar.show
      file_loaded(__FILE__)
    end
  end
end