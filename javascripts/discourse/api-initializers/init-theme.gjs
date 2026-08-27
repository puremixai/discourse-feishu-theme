import { apiInitializer } from "discourse/lib/api";

const HOME_CLASS = "feishu-home";
const TOPIC_CLASS = "feishu-topic";
const DARK_CLASS = "feishu-dark";
const POST_ROWS_THEME_CLASS = "feishu-post-rows-themed";
const POST_ROWS_MODE_KEY = "feishu-post-rows-mode";
let postRowsModeFallback = "document";
let topicToolsCloseTimer;
let topicToolsOutsideBound = false;

function settingValue(key, fallback) {
  if (typeof settings === "undefined" || settings[key] === undefined) {
    return fallback;
  }
  return settings[key];
}

  // 对齐 linux.do 自身的颜色模式：深色配色样式表 link 的 media 表达 浅色/深色/自动
  function isDarkMode() {
    const darkLink = document.querySelector("link.dark-scheme");
    if (!darkLink) return false; // 站点未启用深色配色
    if (darkLink.media === "all") return true; // 用户强制深色
    if (darkLink.media === "none") return false; // 用户强制浅色
    try {
      return window.matchMedia("(prefers-color-scheme: dark)").matches; // 自动：跟随系统
    } catch {
      return false;
    }
  }

  function applyColorMode() {
    document.documentElement.classList.toggle(DARK_CLASS, isDarkMode());
  }

  function makeSidebarSearch() {
    const container = document.querySelector(".sidebar-container");
    if (!container || container.querySelector(".feishu-sidebar-search")) return;

    const search = document.createElement("a");
    search.className = "feishu-sidebar-search";
    search.href = "/search";
    search.innerHTML = `
      <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <circle cx="11" cy="11" r="6.5" stroke="currentColor" stroke-width="2"/>
        <path d="m16 16 4 4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      </svg>
      <span>搜索</span>`;

    const sections = container.querySelector(".sidebar-sections") || container.firstElementChild;
    if (sections) container.insertBefore(search, sections);
    else container.prepend(search);
  }

  function makeHomeHeading() {
    const headerContents = document.querySelector(".d-header .contents");
    if (!headerContents) return;

    let heading = document.querySelector(".feishu-home-heading");
    if (!heading) {
      heading = document.createElement("h1");
      heading.className = "feishu-home-heading";
      heading.textContent = "主页";
    }
    if (heading.parentElement !== headerContents) headerContents.appendChild(heading);
  }

  function makeCreateTopicButton() {
    const controlsRoot = document.querySelector(".navigation-container, .list-controls");
    if (!controlsRoot) return;

    const candidates = [
      ".navigation-container .create-topic",
      ".navigation-controls .create-topic",
      ".navigation-container #create-topic",
      ".navigation-controls #create-topic",
      ".navigation-container button[title*='新建话题']",
      ".navigation-container button[aria-label*='新建话题']",
      ".list-controls button[title*='新建话题']",
      ".list-controls button[aria-label*='新建话题']"
    ];
    let button = document.querySelector(candidates.join(", "));
    if (!button) {
      button = [...controlsRoot.querySelectorAll("button")].find((node) => {
        const label = [
          node.textContent,
          node.title,
          node.getAttribute("aria-label")
        ]
          .filter(Boolean)
          .join(" ")
          .replace(/\s+/g, " ");
        return label.includes("新建话题");
      });
    }
    if (!button) return;

    // Keep this Glimmer-owned node in its original parent. Reparenting it breaks
    // subsequent category route renders; CSS positions the native control instead.
    button.classList.add("feishu-create-topic");
    button.setAttribute("aria-label", "新建话题");
    button.title = "新建话题";

  }

  function makeTopicContext() {
    const headerContents = document.querySelector(".d-header .contents");
    if (!headerContents) return;

    const topicTitle = document.querySelector("#topic-title h1, #topic-title .fancy-title");
    let title = topicTitle?.textContent?.trim().replace(/\s+/g, " ");
    if (!title) {
      // 跳转到中间楼层时 #topic-title 尚未渲染，回退到 tab 标签标题
      title = document.title.replace(/\s*[-–]\s*XAI.RUN\s*$/, "").trim();
    }
    if (!title) return;

    let context = headerContents.querySelector(".feishu-topic-context");
    if (!context) {
      context = document.createElement("div");
      context.className = "feishu-topic-context";
      context.title = "回到第一层";
      context.setAttribute("role", "button");
      context.tabIndex = 0;
      const goToFirstPost = () => {
        const match = location.pathname.match(/^(\/t\/[^/]+\/\d+)/);
        if (!match) return;
        const path = `${match[1]}/1${location.search}${location.hash}`;
        try {
          const DiscourseURL = window.require?.("discourse/lib/url")?.default;
          if (DiscourseURL?.routeTo) {
            DiscourseURL.routeTo(path);
            return;
          }
        } catch { }
        const link = document.createElement("a");
        link.href = path;
        link.style.display = "none";
        document.body.appendChild(link);
        link.click();
        link.remove();
      };
      context.addEventListener("click", goToFirstPost);
      context.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          goToFirstPost();
        }
      });
      headerContents.appendChild(context);
    }

    const routeKey = `${location.pathname}|${title}`;
    if (context.dataset.routeKey === routeKey) return;
    context.dataset.routeKey = routeKey;

    const category = document.querySelector(
      "#topic-title .badge-category__name, #topic-title .badge-wrapper, #topic-title .category-name"
    );
    const categoryText = category?.textContent?.trim().replace(/\s+/g, " ") || "知识库";
    context.replaceChildren();

    const crumbs = document.createElement("div");
    crumbs.className = "feishu-topic-crumbs";
    crumbs.textContent = `知识库  ›  ${categoryText}  ›  ${title}`;

    const meta = document.createElement("div");
    meta.className = "feishu-topic-meta";
    meta.textContent = "内部使用　｜　云端实时保存";

    context.append(crumbs, meta);
  }

  function getTopicKey() {
    return (
      document.querySelector("#topic-title h1[data-topic-id]")?.dataset.topicId ||
      document.querySelector("#topic[data-topic-id]")?.dataset.topicId ||
      location.pathname.match(/^\/t\/[^/]+\/(\d+)/)?.[1] ||
      location.pathname
    );
  }

  function getEditLabel(editTitle) {
    const match = editTitle?.match(/(\d{4})\s*年\s*(\d+)月\s*(\d+)日/);
    if (!match) return "已修改";

    const now = new Date();
    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    if (
      now.getFullYear() === year &&
      now.getMonth() + 1 === month &&
      now.getDate() === day
    ) {
      return "今天修改";
    }

    const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    if (
      yesterday.getFullYear() === year &&
      yesterday.getMonth() + 1 === month &&
      yesterday.getDate() === day
    ) {
      return "昨天修改";
    }

    return "已修改";
  }

  function getPostBody(post) {
    return post?.querySelector(
      ":scope > article > .post__row > .post__body.topic-body"
    );
  }

  function markTopicFullNames(enabled = true) {
    for (const names of document.querySelectorAll(".topic-post .names")) {
      const fullNameNode = names.querySelector(":scope > .full-name");
      const fullName = fullNameNode?.textContent?.trim();
      names.classList.toggle("feishu-has-full-name", enabled && Boolean(fullName));
    }
  }

  function getPostInlineMetadata(post) {
    const postBody = getPostBody(post);
    const postInfos = postBody?.querySelector(
      ":scope > .topic-meta-data > .post-infos"
    );
    const menuArea = postBody?.querySelector(
      ":scope > .post__contents > .post__menu-area"
    );
    const parentPost = postInfos?.querySelector(":scope > .reply-to-tab");
    const parentName = parentPost
      ?.querySelector(":scope > span")
      ?.textContent?.trim()
      .replace(/\s+/g, " ");
    const reactions = menuArea?.querySelector(
      ".reactions-actions-summary .discourse-reactions-counter"
    );
    const reactionCount = reactions
      ?.querySelector(".reactions-counter")
      ?.textContent?.trim()
      .replace(/\s+/g, " ");
    const replies = menuArea?.querySelector(
      ".post-action-menu__show-replies.show-replies"
    );
    const replyCount = replies
      ?.querySelector(".d-button-label")
      ?.textContent?.trim()
      .replace(/\s+/g, " ");
    const items = [];

    if (reactions && reactionCount) {
      items.push({
        kind: "reactions",
        label: `♥ ${reactionCount}`,
        source: reactions
      });
    }
    if (replies && replyCount) {
      items.push({
        kind: "replies",
        label: replyCount,
        source: replies
      });
    }
    if (parentPost && parentName) {
      items.push({
        kind: "parent",
        label: `↩ ${parentName}`,
        source: parentPost
      });
    }

    return items;
  }

  function renderPostInlineMetadata(host, anchor, items) {
    let metadata = host?.querySelector(":scope > .feishu-post-inline-meta");
    if (!host || !anchor || items.length === 0) {
      metadata?.remove();
      return;
    }

    const signature = items
      .map(({ kind, label, source }) =>
        [kind, label, source.getAttribute("aria-expanded") || ""].join(":")
      )
      .join("|");
    const sameSources =
      metadata?._feishuMetaSources?.length === items.length &&
      items.every(({ source }, index) => metadata._feishuMetaSources[index] === source);
    if (
      metadata?.dataset.signature === signature &&
      sameSources &&
      anchor.nextElementSibling === metadata
    ) {
      return;
    }

    metadata?.remove();
    metadata = document.createElement("span");
    metadata.className = "feishu-post-inline-meta";
    metadata.dataset.signature = signature;
    metadata._feishuMetaSources = items.map(({ source }) => source);

    for (const { kind, label, source } of items) {
      const item = document.createElement("button");
      item.className = `feishu-post-inline-meta-item feishu-post-inline-meta-${kind}`;
      item.type = "button";
      item.textContent = label;
      item.title = source.title || source.getAttribute("aria-label") || label;
      item.setAttribute("aria-label", item.title);
      const expanded = source.getAttribute("aria-expanded");
      if (expanded !== null) item.setAttribute("aria-expanded", expanded);
      item.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        source.click();
      });
      metadata.appendChild(item);
    }

    anchor.after(metadata);
  }

  function syncPostInlineMetadata(includePostRows = true) {
    for (const post of document.querySelectorAll(".topic-post[data-post-number]")) {
      if (post.dataset.postNumber === "1") continue;
      const names = getPostBody(post)?.querySelector(
        ":scope > .topic-meta-data > .names"
      );
      if (!includePostRows) {
        names?.querySelector(":scope > .feishu-post-inline-meta")?.remove();
        continue;
      }
      const displayName = names?.classList.contains("feishu-has-full-name")
        ? names.querySelector(":scope > .full-name")
        : names?.querySelector(":scope > .username");
      renderPostInlineMetadata(
        names,
        displayName,
        getPostInlineMetadata(post)
      );
    }

    const firstPost = document.querySelector('.topic-post[data-post-number="1"]');
    const author = document.querySelector(".feishu-doc-author");
    const authorName = author?.querySelector(":scope > .feishu-doc-author-name");
    if (firstPost) {
      renderPostInlineMetadata(author, authorName, getPostInlineMetadata(firstPost));
    } else {
      author?.querySelector(":scope > .feishu-post-inline-meta")?.remove();
    }
  }

  function forwardClonedButtonClick(event, sourceButton, cloneButton) {
    event.preventDefault();
    event.stopPropagation();

    // Floating Kit positions its menu from the original Glimmer-owned trigger.
    // That trigger lives in a hidden menu, so make it report the visible clone's
    // position while keeping the framework-owned node in its original parent.
    sourceButton.getBoundingClientRect = () =>
      cloneButton.isConnected
        ? cloneButton.getBoundingClientRect()
        : HTMLElement.prototype.getBoundingClientRect.call(sourceButton);

    sourceButton.dispatchEvent(new MouseEvent("click", {
      bubbles: true,
      cancelable: true,
      composed: true,
      view: window,
      detail: event.detail,
      screenX: event.screenX,
      screenY: event.screenY,
      clientX: event.clientX,
      clientY: event.clientY,
      ctrlKey: event.ctrlKey,
      shiftKey: event.shiftKey,
      altKey: event.altKey,
      metaKey: event.metaKey,
      button: event.button,
      buttons: event.buttons
    }));
  }

  function syncBoostLists(enabled = true) {
    for (const post of document.querySelectorAll(".topic-post[data-post-number]")) {
      const contents = getPostBody(post)?.querySelector(":scope > .post__contents");
      if (!enabled) {
        contents
          ?.querySelector(":scope > :is(.feishu-inline-boosts, .feishu-boost-table)")
          ?.remove();
        continue;
      }
      const cooked = contents?.querySelector(":scope > .cooked");
      const sourceMenu = contents?.querySelector(
        ":scope > .post__menu-area > .discourse-boosts__post-menu"
      );
      const bubbles = sourceMenu
        ? Array.from(sourceMenu.querySelectorAll(".discourse-boosts__bubble"))
        : [];
      const addButton = sourceMenu?.querySelector(".discourse-boosts__add-btn");
      const sources = bubbles
        .map((bubble) => {
          const button = bubble.querySelector(":scope > .discourse-boosts__cooked");
          const html = bubble.innerHTML?.trim() || "";
          return button && html ? { bubble, button, html } : null;
        })
        .filter(Boolean);
      let boostList = contents?.querySelector(
        ":scope > :is(.feishu-inline-boosts, .feishu-boost-table)"
      );

      if (!contents || !cooked || sources.length === 0) {
        boostList?.remove();
        continue;
      }

      const sourceButtons = [
        ...sources.map(({ button }) => button),
        ...(addButton ? [addButton] : [])
      ];
      const signature = [
        sources.map(({ html }) => html).join("\u001e"),
        addButton ? "can-add" : ""
      ].join("\u001f");
      const sameSources =
        boostList?._feishuBoostSources?.length === sourceButtons.length &&
        sourceButtons.every(
          (button, index) => boostList._feishuBoostSources[index] === button
        );
      if (
        boostList?.classList.contains("feishu-inline-boosts") &&
        boostList.dataset.signature === signature &&
        sameSources &&
        boostList.previousElementSibling === cooked
      ) {
        continue;
      }

      boostList?.remove();
      boostList = document.createElement("div");
      boostList.className = "discourse-boosts__post-menu feishu-inline-boosts";
      boostList.setAttribute("aria-label", "Boost");
      boostList.dataset.signature = signature;
      boostList._feishuBoostSources = sourceButtons;

      const boosts = document.createElement("div");
      boosts.className = "discourse-boosts";
      const list = document.createElement("div");
      list.className = "discourse-boosts__list";

      for (const { bubble, button: sourceButton } of sources) {
        const clone = bubble.cloneNode(true);
        for (const node of clone.querySelectorAll("[id]")) node.removeAttribute("id");
        const cloneButton = clone.querySelector(":scope > .discourse-boosts__cooked");
        cloneButton?.addEventListener("click", (event) => {
          forwardClonedButtonClick(event, sourceButton, cloneButton);
        });
        list.appendChild(clone);
      }

      if (addButton) {
        const clone = addButton.cloneNode(true);
        for (const node of [clone, ...clone.querySelectorAll("[id]")]) {
          node.removeAttribute("id");
        }
        clone.addEventListener("click", (event) => {
          forwardClonedButtonClick(event, addButton, clone);
        });
        list.appendChild(clone);
      }

      boosts.appendChild(list);
      boostList.appendChild(boosts);
      cooked.after(boostList);
    }
  }

  function makeTopicAuthor() {
    const titleWrapper = document.querySelector("#topic-title .title-wrapper");
    const heading = titleWrapper?.querySelector(":scope > h1");
    const firstPost = document.querySelector('.topic-post[data-post-number="1"]');
    const firstPostBody = getPostBody(firstPost);
    const topicKey = getTopicKey();
    const existing = document.querySelector(".feishu-doc-author");

    if (!titleWrapper || !heading || !firstPostBody) {
      if (existing && existing.dataset.topicKey !== topicKey) existing.remove();
      return;
    }

    const sourceUser = firstPostBody.querySelector(
      ":scope > .topic-meta-data .names :is(.full-name, .username) a[data-user-card], :scope > .topic-meta-data .names :is(.full-name, .username) a"
    );
    const sourceFullName = firstPostBody
      .querySelector(
        ":scope > .topic-meta-data .names .full-name"
      )
      ?.textContent?.trim()
      .replace(/\s+/g, " ");
    const sourceAvatar = firstPost.querySelector(
      ":scope > article > .post__row > .topic-avatar .main-avatar img.avatar"
    );
    const sourceUsername = firstPostBody
      .querySelector(
        ":scope > .topic-meta-data .names .username"
      )
      ?.textContent?.trim()
      .replace(/\s+/g, " ");
    const displayName =
      sourceFullName || sourceUsername || sourceUser?.textContent?.trim().replace(/\s+/g, " ");
    if (!sourceUser || !displayName) return;

    const postDate = firstPostBody.querySelector(
      ":scope > .topic-meta-data .post-info.post-date a.post-date"
    );
    const relativeDate =
      postDate?.getAttribute("aria-label") ||
      postDate?.textContent?.trim().replace(/\s+/g, " ") ||
      "";
    const editTitle =
      firstPostBody.querySelector(
        ":scope > .topic-meta-data .post-info.edits button"
      )?.title || "";
    const timeLabel = [
      relativeDate ? `${relativeDate}发布` : "",
      editTitle ? getEditLabel(editTitle) : ""
    ].filter(Boolean).join(" · ");
    const renderKey = [
      topicKey,
      displayName,
      sourceAvatar?.currentSrc || sourceAvatar?.src,
      timeLabel
    ].join("|");

    if (
      existing?.dataset.renderKey === renderKey &&
      existing.parentElement === titleWrapper &&
      existing.previousElementSibling === heading
    ) {
      return;
    }

    existing?.remove();
    const author = document.createElement("div");
    author.className = "feishu-doc-author";
    author.dataset.topicKey = topicKey;
    author.dataset.renderKey = renderKey;

    if (sourceAvatar) {
      const avatarLink = document.createElement("a");
      avatarLink.href = sourceUser.href;
      avatarLink.tabIndex = -1;
      avatarLink.setAttribute("aria-hidden", "true");

      const avatar = document.createElement("img");
      avatar.className = "feishu-doc-author-avatar";
      avatar.src = sourceAvatar.currentSrc || sourceAvatar.src;
      avatar.alt = "";
      avatar.width = 24;
      avatar.height = 24;
      avatarLink.appendChild(avatar);
      author.appendChild(avatarLink);
    }

    const name = document.createElement("a");
    name.className = "feishu-doc-author-name";
    name.href = sourceUser.href;
    name.textContent = displayName;
    const userCard = sourceUser.getAttribute("data-user-card");
    if (userCard) name.setAttribute("data-user-card", userCard);
    author.appendChild(name);

    if (timeLabel) {
      const time = document.createElement("span");
      time.className = "feishu-post-inline-meta-item feishu-doc-author-time";
      time.textContent = timeLabel;
      const publishedTitle =
        postDate?.querySelector(".relative-date[title]")?.title ||
        postDate?.title ||
        relativeDate;
      time.title = [publishedTitle, editTitle].filter(Boolean).join("；");
      author.appendChild(time);
    }

    heading.after(author);
  }

  function getPostRowsMode() {
    try {
      return localStorage.getItem(POST_ROWS_MODE_KEY) === "native"
        ? "native"
        : "document";
    } catch {
      return postRowsModeFallback;
    }
  }

  function setPostRowsMode(mode) {
    postRowsModeFallback = mode;
    try {
      localStorage.setItem(POST_ROWS_MODE_KEY, mode);
    } catch { }
  }

  function makePostStyleToggle(postRowsThemed) {
    let button = document.querySelector(".feishu-post-style-toggle");
    if (!document.body) return;

    if (!button) {
      button = document.createElement("button");
      button.className = "feishu-floating-toggle feishu-post-style-toggle";
      button.type = "button";
      button.addEventListener("click", () => {
        const enableDocumentRows = button.dataset.mode === "native";
        setPostRowsMode(enableDocumentRows ? "document" : "native");
        scheduleApply();
      });
      document.body.appendChild(button);
    }

    const mode = postRowsThemed ? "document" : "native";
    if (button.dataset.mode === mode) return;

    const label = postRowsThemed
      ? "切换到原始帖子样式"
      : "切换到文档帖子样式";
    button.dataset.mode = mode;
    button.setAttribute("aria-label", label);
    button.setAttribute("aria-pressed", String(postRowsThemed));
    button.title = label;
    button.innerHTML = `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M5 7h13m0 0-3-3m3 3-3 3M19 17H6m0 0 3 3m-3-3 3-3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>`;
  }

  function makeBackButton() {
    if (!document.body || document.querySelector(".feishu-back-toggle")) return;

    const button = document.createElement("button");
    button.className = "feishu-floating-toggle feishu-back-toggle";
    button.type = "button";
    button.setAttribute("aria-label", "返回上一页");
    button.title = "返回上一页";
    button.innerHTML = `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="m15 6-6 6 6 6M9 12h10" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>`;
    button.addEventListener("click", () => history.back());
    document.body.appendChild(button);
  }

  function setTopicToolsOpen(button, isOpen) {
    if (isOpen && topicToolsCloseTimer) {
      clearTimeout(topicToolsCloseTimer);
      topicToolsCloseTimer = undefined;
    }
    document.documentElement.classList.toggle("feishu-topic-tools-open", isOpen);
    if (!button) return;
    const label = isOpen ? "收起话题导航" : "展开话题导航";
    button.setAttribute("aria-expanded", String(isOpen));
    button.setAttribute("aria-label", label);
    button.title = label;
  }

  function scheduleTopicToolsClose() {
    clearTimeout(topicToolsCloseTimer);
    topicToolsCloseTimer = setTimeout(() => {
      setTopicToolsOpen(document.querySelector(".feishu-topic-tools-toggle"), false);
      topicToolsCloseTimer = undefined;
    }, 160);
  }

  function makeTopicToolsToggle() {
    const navigation = document.querySelector(".topic-navigation");
    let button = document.querySelector(".feishu-topic-tools-toggle");

    if (!navigation || !document.body) {
      button?.remove();
      document.documentElement.classList.remove("feishu-topic-tools-open");
      return;
    }

    if (!topicToolsOutsideBound) {
      document.addEventListener(
        "pointerdown",
        (event) => {
          if (!document.documentElement.classList.contains("feishu-topic-tools-open")) {
            return;
          }
          const target = event.target;
          if (
            target instanceof Element &&
            target.closest(".topic-navigation, .feishu-topic-tools-toggle")
          ) {
            return;
          }
          setTopicToolsOpen(
            document.querySelector(".feishu-topic-tools-toggle"),
            false
          );
        },
        true
      );
      topicToolsOutsideBound = true;
    }

    navigation.id ||= "feishu-topic-tools-panel";
    if (!navigation.dataset.feishuHoverBound) {
      navigation.dataset.feishuHoverBound = "true";
      navigation.addEventListener("pointerenter", () => {
        clearTimeout(topicToolsCloseTimer);
        topicToolsCloseTimer = undefined;
      });
      navigation.addEventListener("pointerleave", scheduleTopicToolsClose);
    }

    if (!navigation.dataset.feishuReplyCloseBound) {
      navigation.dataset.feishuReplyCloseBound = "true";
      navigation.addEventListener(
        "click",
        (event) => {
          if (!event.target.closest(".reply-to-post")) return;
          requestAnimationFrame(() => {
            setTopicToolsOpen(document.querySelector(".feishu-topic-tools-toggle"), false);
          });
        },
        true
      );
    }

    const topicKey = getTopicKey();
    if (!button) {
      button = document.createElement("button");
      button.className = "feishu-floating-toggle feishu-topic-tools-toggle";
      button.type = "button";
      button.setAttribute("aria-controls", navigation.id);
      button.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M8 7h11M8 12h11M8 17h11" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
          <circle cx="4" cy="7" r="1.25" fill="currentColor"/>
          <circle cx="4" cy="12" r="1.25" fill="currentColor"/>
          <circle cx="4" cy="17" r="1.25" fill="currentColor"/>
        </svg>`;
      button.addEventListener("pointerenter", () => setTopicToolsOpen(button, true));
      button.addEventListener("pointerleave", scheduleTopicToolsClose);
      button.addEventListener("focus", () => setTopicToolsOpen(button, true));
      button.addEventListener("blur", scheduleTopicToolsClose);
      button.addEventListener("click", (event) => {
        const hasHover = window.matchMedia?.("(hover: hover)").matches;
        if (hasHover && event.detail !== 0) return;
        const isOpen = !document.documentElement.classList.contains("feishu-topic-tools-open");
        setTopicToolsOpen(button, isOpen);
      });
      document.body.appendChild(button);
    }

    if (button.dataset.topicKey !== topicKey) {
      setTopicToolsOpen(button, false);
      button.dataset.topicKey = topicKey;
    }
    button.setAttribute("aria-controls", navigation.id);
    const isOpen = document.documentElement.classList.contains("feishu-topic-tools-open");
    setTopicToolsOpen(button, isOpen);
  }

  function makeColumnLabels() {
    const labels = [
      ["th.default, th.main-link", "标题"],
      ["th.posters", "所有者"],
      ["th.posts", "回复"],
      ["th.views", "浏览量"],
      ["th.activity", "最近访问 ↓"]
    ];

    for (const [selector, label] of labels) {
      for (const cell of document.querySelectorAll(`.topic-list-header ${selector}`)) {
        let span = cell.querySelector(":scope > .feishu-column-label");
        if (!span) {
          span = document.createElement("span");
          span.className = "feishu-column-label";
          cell.prepend(span);
        }
        if (span.textContent !== label) span.textContent = label;
      }
    }
  }

  function makeOwnerNames() {
    for (const cell of document.querySelectorAll(".topic-list-item .posters")) {
      const ownerLink = cell.querySelector("[data-user-card]");
      const ownerAvatar = ownerLink?.querySelector("img.avatar");
      const titleAttr = ownerAvatar?.getAttribute("title") || "";
      let ownerName = "";
      if (titleAttr) {
        const idx = titleAttr.lastIndexOf(" - ");
        ownerName = idx > -1 ? titleAttr.slice(0, idx).trim() : titleAttr.trim();
      }
      if (!ownerName) ownerName = ownerLink?.getAttribute("data-user-card")?.trim() || "";
      let label = cell.querySelector(":scope > .feishu-owner-name");

      if (!ownerName) {
        label?.remove();
        continue;
      }

      const avatarSrc = ownerAvatar?.currentSrc || ownerAvatar?.src || "";
      const ownerHref = ownerLink?.getAttribute("href") || "";
      const userCard = ownerLink?.getAttribute("data-user-card") || "";
      const renderKey = `${ownerName}|${avatarSrc}|${ownerHref}`;

      if (!label || label.tagName !== "A") {
        label?.remove();
        label = document.createElement("a");
        label.className = "feishu-owner-name";
        cell.appendChild(label);
      }

      if (label.dataset.renderKey === renderKey) continue;
      label.dataset.renderKey = renderKey;
      label.textContent = "";
      if (ownerHref) label.href = ownerHref;
      if (userCard) label.setAttribute("data-user-card", userCard);

      if (avatarSrc) {
        const img = document.createElement("img");
        img.className = "feishu-owner-avatar";
        img.src = avatarSrc;
        img.loading = "lazy";
        label.appendChild(img);
      }

      const name = document.createElement("span");
      name.className = "feishu-owner-name-text";
      name.textContent = ownerName;
      label.appendChild(name);
    }
  }


  function applyTheme() {

    document.documentElement.classList.toggle("feishu-theme", Boolean(settingValue("enable_document_layout", true)));
    applyColorMode();
    if (!document.body) return;

    const isTopic = /^\/t\//.test(location.pathname);
    const layoutEnabled = Boolean(settingValue("enable_document_layout", true));
    const postRowsThemed = !isTopic || getPostRowsMode() !== "native";
    document.documentElement.classList.toggle(HOME_CLASS, layoutEnabled && !isTopic);
    document.documentElement.classList.toggle(TOPIC_CLASS, layoutEnabled && isTopic);
    document.documentElement.classList.toggle(POST_ROWS_THEME_CLASS, postRowsThemed);
    document.body.classList.toggle(HOME_CLASS, layoutEnabled && !isTopic);
    document.body.classList.toggle(TOPIC_CLASS, layoutEnabled && isTopic);



    makeSidebarSearch();

    const homeHeading = document.querySelector(".feishu-home-heading");
    const topicContext = document.querySelector(".feishu-topic-context");
    if (isTopic) {
      homeHeading?.remove();
      makeTopicContext();
      markTopicFullNames(postRowsThemed);
      syncBoostLists(postRowsThemed);
      makeTopicAuthor();
      syncPostInlineMetadata(postRowsThemed);
      makeTopicToolsToggle();
      makeBackButton();
      makePostStyleToggle(postRowsThemed);
    } else {
      topicContext?.remove();
      document.querySelector(".feishu-doc-author")?.remove();
      for (const button of document.querySelectorAll(".feishu-floating-toggle")) {
        button.remove();
      }
      document.documentElement.classList.remove("feishu-topic-tools-open");
      makeHomeHeading();
      makeCreateTopicButton();
      makeColumnLabels();
      makeOwnerNames();
    }
  }

  let scheduled = false;
  function scheduleApply() {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => {
      scheduled = false;
      applyTheme();
    });
  }

  function bootstrap() {
    if (!document.documentElement) {
      setTimeout(bootstrap, 0);
      return;
    }

    const initialIsTopic = /^\/t\//.test(location.pathname);
    document.documentElement.classList.toggle(
      POST_ROWS_THEME_CLASS,
      !initialIsTopic || getPostRowsMode() !== "native"
    );

    document.documentElement.classList.toggle("feishu-theme", Boolean(settingValue("enable_document_layout", true)));
    applyColorMode();

    try {
      localStorage.removeItem("feishu-theme-mode"); // 清理旧版手动切换的遗留设置
      const colorMedia = window.matchMedia("(prefers-color-scheme: dark)");
      const onColorChange = () => applyColorMode();
      if (colorMedia.addEventListener) {
        colorMedia.addEventListener("change", onColorChange);
      } else if (colorMedia.addListener) {
        colorMedia.addListener(onColorChange);
      }
    } catch { }

    const observer = new MutationObserver(scheduleApply);
    observer.observe(document.documentElement, { childList: true, subtree: true });

    for (const method of ["pushState", "replaceState"]) {
      const original = history[method];
      history[method] = function (...args) {
        const result = original.apply(this, args);
        scheduleApply();
        return result;
      };
    }

    window.addEventListener("popstate", scheduleApply);
    window.addEventListener("hashchange", scheduleApply);
    document.addEventListener("DOMContentLoaded", scheduleApply, { once: true });
    document.addEventListener("turbo:load", scheduleApply);
    document.addEventListener("page:changed", scheduleApply);
    scheduleApply();
  }

export default apiInitializer((api) => {
  bootstrap();
  api.onPageChange(() => scheduleApply());
});
