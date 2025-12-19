SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: update_updated_at_with_current_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_with_current_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: credits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credits (
    id bigint NOT NULL,
    journal_id bigint,
    element_type integer NOT NULL,
    payment_method_type integer NOT NULL,
    account_id integer NOT NULL,
    amount integer NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT credit_element_type CHECK ((element_type = ANY (ARRAY[1, 2, 3, 4, 5]))),
    CONSTRAINT credit_payment_method_type CHECK ((((element_type = 1) AND (payment_method_type = ANY (ARRAY[1, 2, 3]))) OR ((element_type = 2) AND (payment_method_type = ANY (ARRAY[1, 2, 3]))) OR ((element_type = ANY (ARRAY[3, 4, 5])) AND (payment_method_type = 0))))
);


--
-- Name: credits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credits_id_seq OWNED BY public.credits.id;


--
-- Name: debits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.debits (
    id bigint NOT NULL,
    journal_id bigint,
    element_type integer NOT NULL,
    account_id integer NOT NULL,
    amount integer NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT credit_element_type CHECK ((element_type = ANY (ARRAY[1, 2, 3, 4, 5])))
);


--
-- Name: debits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.debits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: debits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.debits_id_seq OWNED BY public.debits.id;


--
-- Name: journals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journals (
    id bigint NOT NULL,
    journal_dt date NOT NULL,
    store_id bigint,
    store_name text,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: journals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.journals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.journals_id_seq OWNED BY public.journals.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    id bigint NOT NULL,
    name text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: stores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stores_id_seq OWNED BY public.stores.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: credits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits ALTER COLUMN id SET DEFAULT nextval('public.credits_id_seq'::regclass);


--
-- Name: debits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits ALTER COLUMN id SET DEFAULT nextval('public.debits_id_seq'::regclass);


--
-- Name: journals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals ALTER COLUMN id SET DEFAULT nextval('public.journals_id_seq'::regclass);


--
-- Name: stores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores ALTER COLUMN id SET DEFAULT nextval('public.stores_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: credits credits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT credits_pkey PRIMARY KEY (id);


--
-- Name: debits debits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits
    ADD CONSTRAINT debits_pkey PRIMARY KEY (id);


--
-- Name: journals journals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals
    ADD CONSTRAINT journals_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_credits_on_journal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credits_on_journal_id ON public.credits USING btree (journal_id);


--
-- Name: index_credits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credits_on_user_id ON public.credits USING btree (user_id);


--
-- Name: index_debits_on_journal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_debits_on_journal_id ON public.debits USING btree (journal_id);


--
-- Name: index_debits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_debits_on_user_id ON public.debits USING btree (user_id);


--
-- Name: index_journals_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_journals_on_store_id ON public.journals USING btree (store_id);


--
-- Name: index_journals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_journals_on_user_id ON public.journals USING btree (user_id);


--
-- Name: credits trigger_update_updated_at_of_credits; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_credits BEFORE UPDATE ON public.credits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: debits trigger_update_updated_at_of_debits; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_debits BEFORE UPDATE ON public.debits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: journals trigger_update_updated_at_of_journals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_journals BEFORE UPDATE ON public.journals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: stores trigger_update_updated_at_of_stores; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_stores BEFORE UPDATE ON public.stores FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: users trigger_update_updated_at_of_users; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_users BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: journals fk_rails_1f2015adde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals
    ADD CONSTRAINT fk_rails_1f2015adde FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: debits fk_rails_410320ab9b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits
    ADD CONSTRAINT fk_rails_410320ab9b FOREIGN KEY (journal_id) REFERENCES public.journals(id);


--
-- Name: journals fk_rails_4cdc69e25e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals
    ADD CONSTRAINT fk_rails_4cdc69e25e FOREIGN KEY (store_id) REFERENCES public.stores(id);


--
-- Name: credits fk_rails_9001739776; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_9001739776 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: credits fk_rails_b19f08971f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_b19f08971f FOREIGN KEY (journal_id) REFERENCES public.journals(id);


--
-- Name: debits fk_rails_e1ba88eebe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits
    ADD CONSTRAINT fk_rails_e1ba88eebe FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20251219051931'),
('20251219051909'),
('20251219045735'),
('20251219045705'),
('20251219045644'),
('20251219045628'),
('20251219044754'),
('20251219044736'),
('20251219044709'),
('20251219044647'),
('20251219041458');

