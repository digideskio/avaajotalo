/*
 * Copyright 2007 Google Inc.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License. You may obtain a copy of
 * the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations under
 * the License.
 */
package org.otalo.ao.client;

import org.otalo.ao.client.model.Forum;
import org.otalo.ao.client.model.Message;

import com.google.gwt.core.client.EntryPoint;
import com.google.gwt.core.client.GWT;
import com.google.gwt.event.logical.shared.ResizeEvent;
import com.google.gwt.event.logical.shared.ResizeHandler;
import com.google.gwt.user.client.Command;
import com.google.gwt.user.client.DeferredCommand;
import com.google.gwt.user.client.Window;
import com.google.gwt.user.client.ui.DockPanel;
import com.google.gwt.user.client.ui.RootPanel;
import com.google.gwt.user.client.ui.VerticalPanel;

/**
 * This application demonstrates how to construct a relatively complex user
 * interface, similar to many common email readers. It has no back-end,
 * populating its components with hard-coded data.
 */
public class Messages implements EntryPoint, ResizeHandler {

  private static Messages singleton;

  /**
   * Instantiate an application-level image bundle. This object will provide
   * programmatic access to all the images needed by widgets.
   */
  private static final Images images = GWT.create(Images.class);

  /**
   * An aggragate image bundle that pulls together all the images for this
   * application into a single bundle.
   */
  public interface Images extends Shortcuts.Images, TopPanel.Images {
  }

  /**
   * Gets the singleton Mail instance.
   */
  public static Messages get() {
    return singleton;
  }

  private TopPanel topPanel = new TopPanel(images);
  private VerticalPanel rightPanel = new VerticalPanel();
  private MessageList messageList;
  private MessageDetail messageDetail = new MessageDetail();
  private ApprovedMessages approvedMessages = new ApprovedMessages();
  private Shortcuts shortcuts = new Shortcuts(images);

  /**
   * Displays the specified item.
   * 
   * @param message
   */
  public void displayMessage(Message message) {
    messageDetail.setItem(message);
  }
  
  public void displayMessages(Forum f, String filterParams, Message m)
  {
  	messageList.getMessages(f, filterParams, m);
  }
  
  public void displayMessages(Forum f, String filterParams)
  {
  	displayMessages(f, filterParams, null);
  }
  
  public void displayMessages(Forum f)
  {
  	displayMessages(f, "", null);
  }
  
  public void setMovable(boolean canMove)
  {
  	messageDetail.setMovable(canMove);
  }
  
  public void setModerated(boolean isModerated)
  {
  	messageDetail.setModerated(isModerated);
  }

  /**
   * This method constructs the application user interface by instantiating
   * controls and hooking up event handler.
   */
  public void onModuleLoad() {
    singleton = this;

    topPanel.setWidth("100%");

    // MailList uses Mail.get() in its constructor, so initialize it after
    // 'singleton'.
    messageList = new MessageList();
    messageList.setWidth("100%");

    // Create the right panel, containing the email list & details.
    rightPanel.add(messageList);
    rightPanel.add(messageDetail);
    rightPanel.setWidth("100%");
    messageDetail.setWidth("100%");
    shortcuts.setWidth("100%");

    // Create a dock panel that will contain the menu bar at the top,
    // the shortcuts to the left, and the mail list & details taking the rest.
    DockPanel outer = new DockPanel();
    outer.add(topPanel, DockPanel.NORTH);
    outer.add(shortcuts, DockPanel.WEST);
    outer.add(rightPanel, DockPanel.CENTER);
    outer.setWidth("100%");

    outer.setSpacing(4);
    outer.setCellWidth(rightPanel, "100%");

    // Hook the window resize event, so that we can adjust the UI.
    Window.addResizeHandler(this);

    // Get rid of scrollbars, and clear out the window's built-in margin,
    // because we want to take advantage of the entire client area.
    Window.enableScrolling(false);
    Window.setMargin("0px");

    // Finally, add the outer panel to the RootPanel, so that it will be
    // displayed.
    RootPanel.get().add(outer);

    // Call the window resized handler to get the initial sizes setup. Doing
    // this in a deferred command causes it to occur after all widgets' sizes
    // have been computed by the browser.
    DeferredCommand.addCommand(new Command() {
      public void execute() {
        onWindowResized(Window.getClientWidth(), Window.getClientHeight());
      }
    });

    onWindowResized(Window.getClientWidth(), Window.getClientHeight());
  }

  public void onResize(ResizeEvent event) {
    onWindowResized(event.getWidth(), event.getHeight());
  }

  public void onWindowResized(int width, int height) {
    // Adjust the shortcut panel and detail area to take up the available room
    // in the window.
    int shortcutHeight = height - shortcuts.getAbsoluteTop() - 8;
    if (shortcutHeight < 1) {
      shortcutHeight = 1;
    }
    shortcuts.setHeight(shortcutHeight + "px");

  }
}
