import "./style.css";

import type { NavContextMenuPatchCallback } from "@api/ContextMenu";
import { openPrivateChannel, sendMessage } from "@utils/discord";
import { sleep } from "@utils/misc";
import definePlugin from "@utils/types";
import { User } from "@vencord/discord-types";
import { ChannelStore, Menu, React, showToast, Toasts, Tooltip, UserStore } from "@webpack/common";

const pending = new Set<string>();

const notify = (message: string, type: string) => {
    try {
        showToast(message, type, { duration: 4000 });
    } catch (error) {
        console.error("Hey wake up!: toast unavailable", error);
    }
};

const WakeIcon = ({ className }: { className?: string; }) => (
    <svg className={className} width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d="M12 22a2.2 2.2 0 0 0 2.12-1.6H9.88A2.2 2.2 0 0 0 12 22Zm7-4-1.6-1.7v-4.5c0-2.7-1.45-4.9-4-5.48V5a1.4 1.4 0 0 0-2.8 0v1.32c-2.55.58-4 2.78-4 5.48v4.5L5 18v1h14v-1ZM4.4 8.1 3 6.7a11.7 11.7 0 0 1 4-3L7.8 5a10 10 0 0 0-3.4 3.1Zm15.2 0A10 10 0 0 0 16.2 5l.8-1.3a11.7 11.7 0 0 1 4 3l-1.4 1.4Z" />
    </svg>
);

const wakeUser = async (user: User, directChannelId?: string): Promise<boolean> => {
    if (pending.has(user.id)) {
        notify("Un message est déjà en cours d'envoi", Toasts.Type.MESSAGE);
        return false;
    }
    pending.add(user.id);
    notify(`Envoi à ${user.globalName || user.username}…`, Toasts.Type.MESSAGE);
    try {
        let channelId = directChannelId || ChannelStore.getDMFromUserId(user.id);
        if (!channelId) {
            const result = await Promise.resolve(openPrivateChannel(user.id, false));
            if (typeof result === "string") channelId = result;
            for (let attempt = 0; !channelId && attempt < 20; attempt++) {
                channelId = ChannelStore.getDMFromUserId(user.id);
                if (!channelId) await sleep(150);
            }
        }
        if (!channelId) throw new Error("Could not open the direct message");
        // The recipient's DM may not be open, so do not wait for its view to become ready.
        const result = await sendMessage(channelId, { content: "Hey wake up!" }, false);
        if (result && typeof result === "object" && "ok" in result && result.ok === false) {
            throw new Error("Discord rejected the message");
        }
        notify(`Hey wake up! envoyé à ${user.globalName || user.username}`, Toasts.Type.SUCCESS);
        return true;
    } catch (error) {
        console.error("Hey wake up!:", error);
        notify("Impossible d'envoyer le message privé", Toasts.Type.FAILURE);
        return false;
    } finally {
        pending.delete(user.id);
    }
};

const WakeButton = ({ user }: { user: User; }) => {
    const [status, setStatus] = React.useState<"idle" | "sending" | "sent" | "failed">("idle");
    const resetTimer = React.useRef<ReturnType<typeof setTimeout>>();
    React.useEffect(() => () => clearTimeout(resetTimer.current), []);
    const label = status === "sending" ? "Envoi en cours…" : status === "sent" ? "Hey wake up! envoyé" : status === "failed" ? "Échec de l'envoi" : "Hey wake up!";
    return (
        <div className={`hey-wake-up hey-wake-up-${status}`}>
            <Tooltip text={label}>
                {({ onMouseEnter, onMouseLeave }) => (
                    <button
                        type="button"
                        aria-label={`${label} : ${user.globalName || user.username}`}
                        disabled={status === "sending"}
                        onMouseEnter={onMouseEnter}
                        onMouseLeave={onMouseLeave}
                        onClick={event => {
                            event.preventDefault();
                            event.stopPropagation();
                            clearTimeout(resetTimer.current);
                            setStatus("sending");
                            void wakeUser(user).then(success => {
                                setStatus(success ? "sent" : "failed");
                                resetTimer.current = setTimeout(() => setStatus("idle"), 4000);
                            });
                        }}
                    >
                        {status === "sending" ? "…" : status === "sent" ? "✓" : status === "failed" ? "!" : <WakeIcon />}
                    </button>
                )}
            </Tooltip>
        </div>
    );
};

const channelAttachMenu: NavContextMenuPatchCallback = (children, props) => {
    const channel = props.channel;
    if (!channel?.isDM()) return;
    const user = UserStore.getUser(channel.getRecipientId());
    if (!user || user.id === UserStore.getCurrentUser()?.id || user.bot) return;
    children.push(
        <Menu.MenuItem
            id="hey-wake-up"
            label="Hey wake up!"
            iconLeft={WakeIcon}
            action={() => void wakeUser(user, channel.id)}
        />
    );
};

export default definePlugin({
    name: "Hey wake up!",
    description: "Send a TeamSpeak-style wake-up message from the voice user list.",
    authors: [{ name: "Vincent-HD", id: 0n }],
    contextMenus: { "channel-attach": channelAttachMenu },
    patches: [{
        find: ".VOICE_PANEL}}",
        replacement: {
            match: /\}\),children:\[(?=.{0,50}#{intl::PRIORITY_SPEAKER})/,
            replace: "$&$self.renderButton(arguments[0]?.user),"
        }
    }],
    renderButton(user: User) {
        if (!user || user.id === UserStore.getCurrentUser()?.id || user.bot) return null;
        return <WakeButton user={user} />;
    }
});
