---
layout: default
title: Interactive Reference
parent: Platform API
nav_order: 1
permalink: /api/reference/
---

# Interactive Reference
{: .no_toc }

Every endpoint, parameter, request body and response in the Platform API (spec `{{ site.data.build.api_spec_version | default: "—" }}`, `Substratal-Version: {{ site.data.build.api_header_version | default: "1" }}`), rendered with Swagger UI from the same `openapi.yaml` the macOS app generates its client from.
{: .fs-6 .fw-300 }

[Download openapi.yaml]({{ '/api/openapi.yaml' | relative_url }}){: .btn .btn-outline } [Versioning](../versioning/){: .btn .btn-outline } [Quick guide](../){: .btn .btn-outline }

**Trying requests.** Production only accepts browser requests from first-party origins, so **Try it out** works against a local devserver, not production:

1. Start the API repository's devserver with this site allowed: `CORS_ALLOWED_ORIGINS={{ site.url }} make run`.
2. Under **Servers**, choose **Local devserver**.
3. Choose **Authorize** and paste a person's access token (API keys are refused from browsers).

Every request this page sends carries `Substratal-Version: {{ site.data.build.api_header_version | default: "1" }}`. For production, copy the request shown for each operation into `curl` or your own client.

<div id="swagger-ui" class="swagger-host">
  <noscript>The interactive reference needs JavaScript. The raw document is at <a href="{{ '/api/openapi.yaml' | relative_url }}">openapi.yaml</a>.</noscript>
</div>

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.33.3/swagger-ui.css">
<script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.33.3/swagger-ui-bundle.js"></script>
<script src="https://cdn.jsdelivr.net/npm/js-yaml@4.1.0/dist/js-yaml.min.js"></script>
<script>
  (function () {
    var specUrl = "{{ '/api/openapi.yaml' | relative_url }}";
    var apiVersion = "{{ site.data.build.api_header_version | default: '1' }}";
    var host = document.getElementById("swagger-ui");

    function render(spec) {
      spec.servers = (spec.servers || []).concat([
        { url: "http://localhost:8080", description: "Local devserver (make run)" }
      ]);
      SwaggerUIBundle({
        spec: spec,
        domNode: host,
        deepLinking: true,
        docExpansion: "none",
        defaultModelsExpandDepth: 0,
        displayOperationId: true,
        displayRequestDuration: true,
        filter: true,
        persistAuthorization: true,
        tryItOutEnabled: false,
        // Every versioned request needs the header; stamp it so no request
        // from this page can go without it.
        requestInterceptor: function (req) {
          req.headers["Substratal-Version"] = apiVersion;
          return req;
        }
      });
    }

    fetch(specUrl)
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.text(); })
      .then(function (text) { render(jsyaml.load(text)); })
      .catch(function (err) {
        host.innerHTML = '<p>Couldn’t load the specification (' + err.message +
          '). The raw document is at <a href="' + specUrl + '">openapi.yaml</a>.</p>';
      });
  })();
</script>
