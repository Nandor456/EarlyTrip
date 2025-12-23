CREATE TABLE IF NOT EXISTS public.chat_groups
(
    group_id integer NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
    name text COLLATE pg_catalog."default",
    group_image text COLLATE pg_catalog."default",
    admin_id integer,
    created_at timestamp with time zone,
    CONSTRAINT chat_group_pkey PRIMARY KEY (group_id)
);

CREATE TABLE IF NOT EXISTS public.friendships
(
    user_id integer NOT NULL,
    friend_id integer NOT NULL,
    status text COLLATE pg_catalog."default" NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT friendships_pkey PRIMARY KEY (user_id, friend_id)
);

CREATE TABLE IF NOT EXISTS public.group_memberships
(
    group_id integer NOT NULL,
    user_id integer NOT NULL,
    CONSTRAINT group_memberships_pkey PRIMARY KEY (group_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.messages
(
    message_id integer NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
    sender_id integer,
    group_id integer,
    content text COLLATE pg_catalog."default",
    message_type text COLLATE pg_catalog."default",
    "timestamp" timestamp with time zone,
    media_url text COLLATE pg_catalog."default",
    CONSTRAINT messages_pkey PRIMARY KEY (message_id)
);

CREATE TABLE IF NOT EXISTS public.schema_migrations
(
    version character varying COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT schema_migrations_pkey PRIMARY KEY (version)
);

CREATE TABLE IF NOT EXISTS public.users
(
    user_id integer NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
    first_name text COLLATE pg_catalog."default",
    last_name text COLLATE pg_catalog."default",
    email text COLLATE pg_catalog."default",
    phone character varying(15) COLLATE pg_catalog."default",
    password text COLLATE pg_catalog."default",
    profile_pic_url text COLLATE pg_catalog."default",
    is_dark_theme boolean NOT NULL DEFAULT true,
    CONSTRAINT users_pkey PRIMARY KEY (user_id)
);

ALTER TABLE IF EXISTS public.friendships
    ADD CONSTRAINT friendships_friend_fk FOREIGN KEY (friend_id)
    REFERENCES public.users (user_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS friendships_friend_id_idx
    ON public.friendships(friend_id);


ALTER TABLE IF EXISTS public.friendships
    ADD CONSTRAINT friendships_user_fk FOREIGN KEY (user_id)
    REFERENCES public.users (user_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE;


ALTER TABLE IF EXISTS public.group_memberships
    ADD CONSTRAINT "group_membership_group_id_FK" FOREIGN KEY (group_id)
    REFERENCES public.chat_groups (group_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID;


ALTER TABLE IF EXISTS public.group_memberships
    ADD CONSTRAINT "group_membership_user_id_FK" FOREIGN KEY (user_id)
    REFERENCES public.users (user_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;
CREATE INDEX IF NOT EXISTS group_memberships_user_id_idx
    ON public.group_memberships(user_id);


ALTER TABLE IF EXISTS public.messages
    ADD CONSTRAINT "messages_group_id_FK" FOREIGN KEY (group_id)
    REFERENCES public.chat_groups (group_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID;


ALTER TABLE IF EXISTS public.messages
    ADD CONSTRAINT "messages_sender_id_FK" FOREIGN KEY (sender_id)
    REFERENCES public.users (user_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;