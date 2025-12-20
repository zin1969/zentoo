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
-- Name: asset_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asset_accounts (
    id bigint NOT NULL,
    asset_type integer NOT NULL,
    name text NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT asset_account_asset_type CHECK ((asset_type = ANY (ARRAY[1, 2, 3])))
);


--
-- Name: asset_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.asset_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: asset_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.asset_accounts_id_seq OWNED BY public.asset_accounts.id;


--
-- Name: credit_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_cards (
    id bigint NOT NULL,
    liability_account_id bigint,
    bank_account_id bigint,
    cutoff_day integer NOT NULL,
    payment_day integer NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT credit_cards_cutoff_day_check CHECK (((cutoff_day >= 1) AND (cutoff_day <= 31))),
    CONSTRAINT credit_cards_payment_day_check CHECK (((payment_day >= 1) AND (payment_day <= 31)))
);


--
-- Name: credit_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credit_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credit_cards_id_seq OWNED BY public.credit_cards.id;


--
-- Name: credit_cards_updated_at_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_cards_updated_at_triggers (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: credit_cards_updated_at_triggers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credit_cards_updated_at_triggers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_cards_updated_at_triggers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credit_cards_updated_at_triggers_id_seq OWNED BY public.credit_cards_updated_at_triggers.id;


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
-- Name: direct_debit_journals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.direct_debit_journals (
    id bigint NOT NULL,
    original_id bigint,
    direct_debit_id bigint,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: direct_debit_journals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.direct_debit_journals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: direct_debit_journals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.direct_debit_journals_id_seq OWNED BY public.direct_debit_journals.id;


--
-- Name: direct_debit_journals_updated_at_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.direct_debit_journals_updated_at_triggers (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: direct_debit_journals_updated_at_triggers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.direct_debit_journals_updated_at_triggers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: direct_debit_journals_updated_at_triggers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.direct_debit_journals_updated_at_triggers_id_seq OWNED BY public.direct_debit_journals_updated_at_triggers.id;


--
-- Name: equity_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equity_accounts (
    id bigint NOT NULL,
    name text NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: equity_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.equity_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: equity_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.equity_accounts_id_seq OWNED BY public.equity_accounts.id;


--
-- Name: expense_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expense_accounts (
    id bigint NOT NULL,
    parent_id bigint,
    name text NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: expense_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.expense_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: expense_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.expense_accounts_id_seq OWNED BY public.expense_accounts.id;


--
-- Name: holiday_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.holiday_types (
    id bigint NOT NULL,
    name text NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: holiday_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.holiday_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: holiday_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.holiday_types_id_seq OWNED BY public.holiday_types.id;


--
-- Name: holidays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.holidays (
    id bigint NOT NULL,
    holiday date NOT NULL,
    holiday_type_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: holidays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.holidays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: holidays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.holidays_id_seq OWNED BY public.holidays.id;


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
-- Name: liability_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.liability_accounts (
    id bigint NOT NULL,
    liability_type integer NOT NULL,
    name text NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT liability_account_liability_type CHECK ((liability_type = ANY (ARRAY[1, 2, 3])))
);


--
-- Name: liability_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.liability_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: liability_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.liability_accounts_id_seq OWNED BY public.liability_accounts.id;


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
-- Name: asset_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_accounts ALTER COLUMN id SET DEFAULT nextval('public.asset_accounts_id_seq'::regclass);


--
-- Name: credit_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards ALTER COLUMN id SET DEFAULT nextval('public.credit_cards_id_seq'::regclass);


--
-- Name: credit_cards_updated_at_triggers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards_updated_at_triggers ALTER COLUMN id SET DEFAULT nextval('public.credit_cards_updated_at_triggers_id_seq'::regclass);


--
-- Name: credits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits ALTER COLUMN id SET DEFAULT nextval('public.credits_id_seq'::regclass);


--
-- Name: debits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits ALTER COLUMN id SET DEFAULT nextval('public.debits_id_seq'::regclass);


--
-- Name: direct_debit_journals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals ALTER COLUMN id SET DEFAULT nextval('public.direct_debit_journals_id_seq'::regclass);


--
-- Name: direct_debit_journals_updated_at_triggers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals_updated_at_triggers ALTER COLUMN id SET DEFAULT nextval('public.direct_debit_journals_updated_at_triggers_id_seq'::regclass);


--
-- Name: equity_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equity_accounts ALTER COLUMN id SET DEFAULT nextval('public.equity_accounts_id_seq'::regclass);


--
-- Name: expense_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_accounts ALTER COLUMN id SET DEFAULT nextval('public.expense_accounts_id_seq'::regclass);


--
-- Name: holiday_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holiday_types ALTER COLUMN id SET DEFAULT nextval('public.holiday_types_id_seq'::regclass);


--
-- Name: holidays id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holidays ALTER COLUMN id SET DEFAULT nextval('public.holidays_id_seq'::regclass);


--
-- Name: journals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals ALTER COLUMN id SET DEFAULT nextval('public.journals_id_seq'::regclass);


--
-- Name: liability_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liability_accounts ALTER COLUMN id SET DEFAULT nextval('public.liability_accounts_id_seq'::regclass);


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
-- Name: asset_accounts asset_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_accounts
    ADD CONSTRAINT asset_accounts_pkey PRIMARY KEY (id);


--
-- Name: credit_cards credit_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT credit_cards_pkey PRIMARY KEY (id);


--
-- Name: credit_cards_updated_at_triggers credit_cards_updated_at_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards_updated_at_triggers
    ADD CONSTRAINT credit_cards_updated_at_triggers_pkey PRIMARY KEY (id);


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
-- Name: direct_debit_journals direct_debit_journals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals
    ADD CONSTRAINT direct_debit_journals_pkey PRIMARY KEY (id);


--
-- Name: direct_debit_journals_updated_at_triggers direct_debit_journals_updated_at_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals_updated_at_triggers
    ADD CONSTRAINT direct_debit_journals_updated_at_triggers_pkey PRIMARY KEY (id);


--
-- Name: equity_accounts equity_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equity_accounts
    ADD CONSTRAINT equity_accounts_pkey PRIMARY KEY (id);


--
-- Name: expense_accounts expense_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_accounts
    ADD CONSTRAINT expense_accounts_pkey PRIMARY KEY (id);


--
-- Name: holiday_types holiday_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holiday_types
    ADD CONSTRAINT holiday_types_pkey PRIMARY KEY (id);


--
-- Name: holidays holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holidays
    ADD CONSTRAINT holidays_pkey PRIMARY KEY (id);


--
-- Name: journals journals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals
    ADD CONSTRAINT journals_pkey PRIMARY KEY (id);


--
-- Name: liability_accounts liability_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liability_accounts
    ADD CONSTRAINT liability_accounts_pkey PRIMARY KEY (id);


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
-- Name: index_asset_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_asset_accounts_on_user_id ON public.asset_accounts USING btree (user_id);


--
-- Name: index_credit_cards_on_bank_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_cards_on_bank_account_id ON public.credit_cards USING btree (bank_account_id);


--
-- Name: index_credit_cards_on_liability_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_cards_on_liability_account_id ON public.credit_cards USING btree (liability_account_id);


--
-- Name: index_credit_cards_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_cards_on_user_id ON public.credit_cards USING btree (user_id);


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
-- Name: index_direct_debit_journals_on_direct_debit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_direct_debit_journals_on_direct_debit_id ON public.direct_debit_journals USING btree (direct_debit_id);


--
-- Name: index_direct_debit_journals_on_original_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_direct_debit_journals_on_original_id ON public.direct_debit_journals USING btree (original_id);


--
-- Name: index_direct_debit_journals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_direct_debit_journals_on_user_id ON public.direct_debit_journals USING btree (user_id);


--
-- Name: index_equity_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_equity_accounts_on_user_id ON public.equity_accounts USING btree (user_id);


--
-- Name: index_expense_accounts_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expense_accounts_on_parent_id ON public.expense_accounts USING btree (parent_id);


--
-- Name: index_expense_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expense_accounts_on_user_id ON public.expense_accounts USING btree (user_id);


--
-- Name: index_holidays_on_holiday_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_holidays_on_holiday_type_id ON public.holidays USING btree (holiday_type_id);


--
-- Name: index_journals_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_journals_on_store_id ON public.journals USING btree (store_id);


--
-- Name: index_journals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_journals_on_user_id ON public.journals USING btree (user_id);


--
-- Name: index_liability_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_liability_accounts_on_user_id ON public.liability_accounts USING btree (user_id);


--
-- Name: asset_accounts trigger_update_updated_at_of_asset_accounts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_asset_accounts BEFORE UPDATE ON public.asset_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: credits trigger_update_updated_at_of_credits; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_credits BEFORE UPDATE ON public.credits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: debits trigger_update_updated_at_of_debits; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_debits BEFORE UPDATE ON public.debits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: equity_accounts trigger_update_updated_at_of_equity_accounts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_equity_accounts BEFORE UPDATE ON public.equity_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: expense_accounts trigger_update_updated_at_of_expense_accounts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_expense_accounts BEFORE UPDATE ON public.expense_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: holiday_types trigger_update_updated_at_of_holiday_types; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_holiday_types BEFORE UPDATE ON public.holiday_types FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: holidays trigger_update_updated_at_of_holidays; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_holidays BEFORE UPDATE ON public.holidays FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: journals trigger_update_updated_at_of_journals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_journals BEFORE UPDATE ON public.journals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: liability_accounts trigger_update_updated_at_of_liability_accounts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_liability_accounts BEFORE UPDATE ON public.liability_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: stores trigger_update_updated_at_of_stores; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_stores BEFORE UPDATE ON public.stores FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: users trigger_update_updated_at_of_users; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_users BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: credit_cards fk_rails_069bf994f3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT fk_rails_069bf994f3 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: liability_accounts fk_rails_0999c965ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liability_accounts
    ADD CONSTRAINT fk_rails_0999c965ca FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: journals fk_rails_1f2015adde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals
    ADD CONSTRAINT fk_rails_1f2015adde FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: direct_debit_journals fk_rails_29f8d7e878; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals
    ADD CONSTRAINT fk_rails_29f8d7e878 FOREIGN KEY (direct_debit_id) REFERENCES public.journals(id);


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
-- Name: credit_cards fk_rails_6ee196f565; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT fk_rails_6ee196f565 FOREIGN KEY (liability_account_id) REFERENCES public.liability_accounts(id);


--
-- Name: equity_accounts fk_rails_7ac996d2ab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equity_accounts
    ADD CONSTRAINT fk_rails_7ac996d2ab FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: credits fk_rails_9001739776; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_9001739776 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: direct_debit_journals fk_rails_b0186ae2fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals
    ADD CONSTRAINT fk_rails_b0186ae2fd FOREIGN KEY (original_id) REFERENCES public.journals(id);


--
-- Name: credits fk_rails_b19f08971f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_b19f08971f FOREIGN KEY (journal_id) REFERENCES public.journals(id);


--
-- Name: expense_accounts fk_rails_b22d405b10; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_accounts
    ADD CONSTRAINT fk_rails_b22d405b10 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: holidays fk_rails_c617b5318d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holidays
    ADD CONSTRAINT fk_rails_c617b5318d FOREIGN KEY (holiday_type_id) REFERENCES public.holiday_types(id);


--
-- Name: expense_accounts fk_rails_c6921d9c71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_accounts
    ADD CONSTRAINT fk_rails_c6921d9c71 FOREIGN KEY (parent_id) REFERENCES public.expense_accounts(id);


--
-- Name: credit_cards fk_rails_ccaff89dd6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT fk_rails_ccaff89dd6 FOREIGN KEY (bank_account_id) REFERENCES public.asset_accounts(id);


--
-- Name: asset_accounts fk_rails_d5e7f3287d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_accounts
    ADD CONSTRAINT fk_rails_d5e7f3287d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: debits fk_rails_e1ba88eebe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits
    ADD CONSTRAINT fk_rails_e1ba88eebe FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: direct_debit_journals fk_rails_f395144e79; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals
    ADD CONSTRAINT fk_rails_f395144e79 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20251220025518'),
('20251220025453'),
('20251220025037'),
('20251220025023'),
('20251220024035'),
('20251220024020'),
('20251220021750'),
('20251220021736'),
('20251220015651'),
('20251220015554'),
('20251220014440'),
('20251220014419'),
('20251220013210'),
('20251220013146'),
('20251220011411'),
('20251220011323'),
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

