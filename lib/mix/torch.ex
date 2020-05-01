defmodule Mix.Torch do
  @moduledoc false

  alias Torch.Config

  def parse_config!(task, args) do
    {opts, _, _} = OptionParser.parse(args, switches: [format: :string, app: :string])

    format = opts[:format] || Config.template_format()
    template_source = opts[:template_source] || Config.template_source()
    otp_app = opts[:app] || Config.otp_app()

    unless otp_app do
      Mix.raise("""
      You need to specify an OTP app to generate files within. Either
      configure it as shown below or pass it in via the `--app` option.

          config :torch,
            otp_app: :my_app

          # Alternatively
          mix #{task} --app my_app
      """)
    end

    unless format in ["eex", "slim"] do
      Mix.raise("""
      Template format is invalid: #{inspect(format)}. Either configure it as
      shown below or pass it via the `--format` option.

          config :torch,
            template_format: :slim

          # Alternatively
          mix #{task} --format slim

      Supported formats: eex, slim
      """)
    end

    unless template_source in ["local", :local, :torch, :phoenix] do
      Mix.raise("""
      Template source is invalid: #{inspect(template_source)}. Either configure it as
      shown below or pass it via the `--template-source` option.

          config :torch,
            template_source: :local

          # Alternatively
          mix #{task} --template-source local

      Supported formats: local, torch
      """)
    end

    %{otp_app: otp_app, format: format, template_source: template_source}
  end

  def copy_from(source_dir, template_source, mapping) when is_list(mapping) do
    custom_path =
      case template_source do
        :local -> File.cwd!()
        "local" -> File.cwd!()
        _ -> Application.app_dir(template_source)
      end

    torch_path = Application.app_dir(:torch)

    for {source_file_path, target_file_path} <- mapping do
      runtime_source =
        [custom_path, source_dir, source_file_path]
        |> Path.join()

      torch_source =
        [torch_path, source_dir, source_file_path]
        |> Path.join()

      file_source =
        case File.exists?(runtime_source) do
          true -> runtime_source
          false -> torch_source
        end

      contents =
        file_source
        |> File.read!()

      Mix.Generator.create_file(target_file_path, contents)
    end
  end

  def inject_templates("phx.gen.html", format, template_source) do
    copy_from("priv/templates/#{format}/phx.gen.html", template_source, [
      {"controller_test.exs", "priv/templates/phx.gen.html/controller_test.exs"},
      {"controller.ex", "priv/templates/phx.gen.html/controller.ex"},
      {"edit.html.#{format}", "priv/templates/phx.gen.html/edit.html.#{format}"},
      {"form.html.#{format}", "priv/templates/phx.gen.html/form.html.#{format}"},
      {"index.html.#{format}", "priv/templates/phx.gen.html/index.html.#{format}"},
      {"new.html.#{format}", "priv/templates/phx.gen.html/new.html.#{format}"},
      {"show.html.#{format}", "priv/templates/phx.gen.html/show.html.#{format}"},
      {"view.ex", "priv/templates/phx.gen.html/view.ex"}
    ])
  end

  def inject_templates("phx.gen.context", _format, template_source) do
    copy_from("priv/templates/phx.gen.context", template_source, [
      {"access_no_schema.ex", "priv/templates/phx.gen.context/access_no_schema.ex"},
      {"context.ex", "priv/templates/phx.gen.context/context.ex"},
      {"schema_access.ex", "priv/templates/phx.gen.context/schema_access.ex"},
      {"test_cases.exs", "priv/templates/phx.gen.context/test_cases.exs"},
      {"context_test.exs", "priv/templates/phx.gen.context/context_test.exs"}
    ])
  end

  def backup_project_templates(mix_task_name) do
    File.rename("priv/templates/#{mix_task_name}", "priv/templates/#{mix_task_name}_backup")
  end

  def restore_project_templates(mix_task_name) do
    File.rename("priv/templates/#{mix_task_name}_backup", "priv/templates/#{mix_task_name}")
  end

  def remove_templates(template_dir) do
    File.rm_rf("priv/templates/#{template_dir}/")
  end
end
