$(document).ready(function() {
  Shiny.addCustomMessageHandler("show-approval-message", function(data) {
    var approvalId = "approval-" + data.request_id;

    var html = '<div id="' + approvalId + '" style="display: flex; gap: 0.5rem; margin: 0.5rem; padding: 0.5rem; align-items: center;">' +
      '<button class="btn btn-sm approval-reject" data-request-id="' + data.request_id + '" style="background-color: #f8f9fa; border: 1px solid #dee2e6; color: #dc3545; font-weight: 500; padding: 0.375rem 0.75rem;">Reject</button>' +
      '<button class="btn btn-sm approval-approve" data-request-id="' + data.request_id + '" style="background-color: #f8f9fa; border: 1px solid #dee2e6; color: #28a745; font-weight: 500; padding: 0.375rem 0.75rem;">Approve</button>' +
    '</div>';

    var container = $("shiny-chat-messages");

    if (container.length === 0) {
      return;
    }

    // Wait a bit for the tool request UI to render first
    setTimeout(function() {
      // Insert AFTER the container, not inside it
      container.after(html);

      var inserted = $("#" + approvalId);

      // Bind click handlers after appending
      $("#" + approvalId + " .approval-reject").on("click", function() {
        var requestId = $(this).data("request-id");
        $("#" + approvalId).fadeOut(200);
        Shiny.setInputValue('tool_approval_response', {
          request_id: requestId,
          approved: false
        }, {priority: 'event'});
      });

      $("#" + approvalId + " .approval-approve").on("click", function() {
        var requestId = $(this).data("request-id");

        $("#" + approvalId).fadeOut(200);

        Shiny.setInputValue('tool_approval_response', {
          request_id: requestId,
          approved: true
        }, {priority: 'event'});
      });
    }, 100);
  });

  Shiny.addCustomMessageHandler("hide-approval-message", function(data) {
    var approvalId = "approval-" + data.request_id;
    $("#" + approvalId).fadeOut(200);
  });
});
