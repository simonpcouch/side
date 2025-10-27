$(document).ready(function() {
  Shiny.addCustomMessageHandler("show-approval-message", function(data) {
    var approvalWrapperId = "approval-wrapper-" + data.request_id;

    var container = $("shiny-chat-messages");

    if (container.length === 0) {
      return;
    }

    // Wait a bit for any pending UI updates
    setTimeout(function() {
      // Create wrapper div for the tool card + approval buttons
      var wrapper = $('<div id="' + approvalWrapperId + '" class="approval-request-wrapper"></div>');

      // Insert the shinychat tool card HTML
      wrapper.append(data.tool_card_html);

      // Create approval buttons container
      var buttonsHtml = '<div class="approval-buttons">' +
        '<button class="btn btn-sm approval-reject" data-request-id="' + data.request_id + '">Reject</button>' +
        '<button class="btn btn-sm approval-approve" data-request-id="' + data.request_id + '">Approve</button>' +
        '</div>';

      wrapper.append(buttonsHtml);

      // Insert after chat messages container
      container.after(wrapper);

      // Bind click handlers
      wrapper.find(".approval-reject").on("click", function() {
        var requestId = $(this).data("request-id");
        $("#" + approvalWrapperId).fadeOut(200, function() {
          $(this).remove();
        });
        Shiny.setInputValue('tool_approval_response', {
          request_id: requestId,
          approved: false
        }, {priority: 'event'});
      });

      wrapper.find(".approval-approve").on("click", function() {
        var requestId = $(this).data("request-id");
        $("#" + approvalWrapperId).fadeOut(200, function() {
          $(this).remove();
        });
        Shiny.setInputValue('tool_approval_response', {
          request_id: requestId,
          approved: true
        }, {priority: 'event'});
      });
    }, 100);
  });

  Shiny.addCustomMessageHandler("hide-approval-message", function(data) {
    var approvalWrapperId = "approval-wrapper-" + data.request_id;
    $("#" + approvalWrapperId).fadeOut(200, function() {
      $(this).remove();
    });
  });
});
