CREATE OR REPLACE FUNCTION disclosure_problems(
	certificateID		ccadb_certificate.CERTIFICATE_ID%TYPE,
	trustContextID		trust_context.ID%TYPE
) RETURNS text[]
AS $$
DECLARE
	t_ccadbCertificate		ccadb_certificate%ROWTYPE;
	t_disclosureStatus		disclosure_status_type;
	t_problems				text[];
	t_url1					text;
	t_url2					text;
	t_type1					text;
	t_type2					text;
	t_date1					text;
	t_date2					text;
	t_start1				text;
	t_start2				text;
	t_end1					text;
	t_end2					text;
BEGIN
	SELECT cc.*
		INTO t_ccadbCertificate
		FROM ccadb_certificate cc
		WHERE cc.CERTIFICATE_ID = certificateID;

	IF trustContextID = 5 THEN
		t_disclosureStatus := t_ccadbCertificate.MOZILLA_DISCLOSURE_STATUS;
	ELSIF trustContextID = 1 THEN
		t_disclosureStatus := t_ccadbCertificate.MICROSOFT_DISCLOSURE_STATUS;
	ELSE
		RETURN NULL;
	END IF;

	IF t_disclosureStatus = 'DisclosureIncomplete' THEN
		IF coalesce(t_ccadbCertificate.CP_URL, t_ccadbCertificate.CPS_URL) IS NULL THEN
			t_problems := array_append(t_problems, '"Certificate Policy (CP)" and/or "Certification Practice Statement (CPS)" is required');
		END IF;
		IF t_ccadbCertificate.STANDARD_AUDIT_URL IS NULL THEN
			t_problems := array_append(t_problems, '"Standard Audit" URL is required');
		END IF;
		IF t_ccadbCertificate.STANDARD_AUDIT_TYPE IS NULL THEN
			t_problems := array_append(t_problems, '"Standard Audit Type" is required');
		END IF;
		IF t_ccadbCertificate.STANDARD_AUDIT_DATE IS NULL THEN
			t_problems := array_append(t_problems, '"Standard Audit Statement Date" is required');
		END IF;
		IF t_ccadbCertificate.STANDARD_AUDIT_START IS NULL THEN
			t_problems := array_append(t_problems, '"Standard Audit Period Start Date" is required');
		END IF;
		IF t_ccadbCertificate.STANDARD_AUDIT_END IS NULL THEN
			t_problems := array_append(t_problems, '"Standard Audit Period End Date" is required');
		END IF;

		PERFORM
			FROM certificate c, ca_trust_purpose ctp
			WHERE c.ID = t_ccadbCertificate.CERTIFICATE_ID
				AND c.ISSUER_CA_ID = ctp.CA_ID
				AND ctp.TRUST_CONTEXT_ID = trustContextID
				AND ctp.TRUST_PURPOSE_ID = 1
				AND (
					x509_isEKUPermitted(c.CERTIFICATE, '1.3.6.1.5.5.7.3.1')
					OR x509_isEKUPermitted(c.CERTIFICATE, '1.3.6.1.4.1.311.10.3.3')	-- MS SGC.
					OR x509_isEKUPermitted(c.CERTIFICATE, '2.16.840.1.113730.4.1')	-- NS Step-Up.
				);
		IF FOUND THEN
			IF t_ccadbCertificate.BRSSL_AUDIT_URL IS NULL THEN
				t_problems := array_append(t_problems, '"BR Audit" URL is required');
			END IF;
			IF t_ccadbCertificate.BRSSL_AUDIT_TYPE IS NULL THEN
				t_problems := array_append(t_problems, '"BR Audit Type" is required');
			END IF;
			IF t_ccadbCertificate.BRSSL_AUDIT_DATE IS NULL THEN
				t_problems := array_append(t_problems, '"BR Audit Statement Date" is required');
			END IF;
			IF t_ccadbCertificate.BRSSL_AUDIT_START IS NULL THEN
				t_problems := array_append(t_problems, '"BR Audit Period Start Date" is required');
			END IF;
			IF t_ccadbCertificate.BRSSL_AUDIT_END IS NULL THEN
				t_problems := array_append(t_problems, '"BR Audit Period End Date" is required');
			END IF;
		END IF;

		PERFORM
			FROM certificate c, ca_trust_purpose ctp, trust_purpose tp
			WHERE c.ID = t_ccadbCertificate.CERTIFICATE_ID
				AND c.ISSUER_CA_ID = ctp.CA_ID
				AND ctp.TRUST_CONTEXT_ID = trustContextID
				AND ctp.TRUST_PURPOSE_ID >= 100
				AND ctp.TRUST_PURPOSE_ID = tp.ID
				AND x509_isPolicyPermitted(c.CERTIFICATE, tp.PURPOSE_OID)
				AND (
					x509_isEKUPermitted(c.CERTIFICATE, '1.3.6.1.5.5.7.3.1')
					OR x509_isEKUPermitted(c.CERTIFICATE, '1.3.6.1.4.1.311.10.3.3')	-- MS SGC.
					OR x509_isEKUPermitted(c.CERTIFICATE, '2.16.840.1.113730.4.1')	-- NS Step-Up.
				);
		IF FOUND THEN
			IF t_ccadbCertificate.EVSSL_AUDIT_URL IS NULL THEN
				t_problems := array_append(t_problems, '"EV Audit" URL is required');
			END IF;
			IF t_ccadbCertificate.EVSSL_AUDIT_TYPE IS NULL THEN
				t_problems := array_append(t_problems, '"EV Audit Type" is required');
			END IF;
			IF t_ccadbCertificate.EVSSL_AUDIT_DATE IS NULL THEN
				t_problems := array_append(t_problems, '"EV Audit Statement Date" is required');
			END IF;
			IF t_ccadbCertificate.EVSSL_AUDIT_START IS NULL THEN
				t_problems := array_append(t_problems, '"EV Audit Period Start Date" is required');
			END IF;
			IF t_ccadbCertificate.EVSSL_AUDIT_END IS NULL THEN
				t_problems := array_append(t_problems, '"EV Audit Period End Date" is required');
			END IF;
		END IF;

	ELSIF t_disclosureStatus = 'DisclosedWithInconsistentAudit' THEN
		SELECT min(coalesce(cc2.STANDARD_AUDIT_URL, '&lt;omitted&gt;')), max(coalesce(cc2.STANDARD_AUDIT_URL, '&lt;omitted&gt;')),
				min(coalesce(cc2.STANDARD_AUDIT_TYPE, '&lt;omitted&gt;')), max(coalesce(cc2.STANDARD_AUDIT_TYPE, '&lt;omitted&gt;')),
				min(coalesce(cc2.STANDARD_AUDIT_DATE::text, '&lt;omitted&gt;')), max(coalesce(cc2.STANDARD_AUDIT_DATE::text, '&lt;omitted&gt;')),
				min(coalesce(cc2.STANDARD_AUDIT_START::text, '&lt;omitted&gt;')), max(coalesce(cc2.STANDARD_AUDIT_START::text, '&lt;omitted&gt;')),
				min(coalesce(cc2.STANDARD_AUDIT_END::text, '&lt;omitted&gt;')), max(coalesce(cc2.STANDARD_AUDIT_END::text, '&lt;omitted&gt;'))
			INTO t_url1, t_url2,
				t_type1, t_type2,
				t_date1, t_date2,
				t_start1, t_start2,
				t_end1, t_end2
			FROM ca_certificate cac, ca_certificate cac2, ccadb_certificate cc2
			WHERE cac.CERTIFICATE_ID = certificateID
				AND cac.CA_ID = cac2.CA_ID
				AND EXISTS (
					SELECT 1
						FROM certificate c, ca_trust_purpose ctp
						WHERE c.ID = cac2.CERTIFICATE_ID
							AND x509_notAfter(c.CERTIFICATE) > statement_timestamp() AT TIME ZONE 'UTC'
							AND c.ISSUER_CA_ID = ctp.CA_ID
							AND ctp.TRUST_CONTEXT_ID = trustContextID
							AND NOT ctp.ALL_CHAINS_REVOKED_IN_SALESFORCE
							AND ctp.IS_TIME_VALID
				)
				AND cac2.CERTIFICATE_ID = cc2.CERTIFICATE_ID
				AND cc2.CCADB_RECORD_ID IS NOT NULL;	-- Ignore CA certificates not in CCADB (e.g., kernel mode cross-certificates).
		IF t_url1 != t_url2 THEN
			t_problems := array_append(t_problems, '"Standard Audit" URLs: ' || t_url1 || ' != ' || t_url2);
		END IF;
		IF t_type1 != t_type2 THEN
			t_problems := array_append(t_problems, '"Standard Audit Type"s: ' || t_type1 || ' != ' || t_type2);
		END IF;
		IF t_date1 != t_date2 THEN
			t_problems := array_append(t_problems, '"Standard Audit Statement Date"s: ' || t_date1 || ' != ' || t_date2);
		END IF;
		IF t_start1 != t_start2 THEN
			t_problems := array_append(t_problems, '"Standard Audit Period Start Date"s: ' || t_start1 || ' != ' || t_start2);
		END IF;
		IF t_end1 != t_end2 THEN
			t_problems := array_append(t_problems, '"Standard Audit Period End Date"s: ' || t_end1 || ' != ' || t_end2);
		END IF;

		SELECT min(coalesce(cc2.BRSSL_AUDIT_URL, '&lt;omitted&gt;')), max(coalesce(cc2.BRSSL_AUDIT_URL, '&lt;omitted&gt;')),
				min(coalesce(cc2.BRSSL_AUDIT_TYPE, '&lt;omitted&gt;')), max(coalesce(cc2.BRSSL_AUDIT_TYPE, '&lt;omitted&gt;')),
				min(coalesce(cc2.BRSSL_AUDIT_DATE::text, '&lt;omitted&gt;')), max(coalesce(cc2.BRSSL_AUDIT_DATE::text, '&lt;omitted&gt;')),
				min(coalesce(cc2.BRSSL_AUDIT_START::text, '&lt;omitted&gt;')), max(coalesce(cc2.BRSSL_AUDIT_START::text, '&lt;omitted&gt;')),
				min(coalesce(cc2.BRSSL_AUDIT_END::text, '&lt;omitted&gt;')), max(coalesce(cc2.BRSSL_AUDIT_END::text, '&lt;omitted&gt;'))
			INTO t_url1, t_url2,
				t_type1, t_type2,
				t_date1, t_date2,
				t_start1, t_start2,
				t_end1, t_end2
			FROM ca_certificate cac, ca_certificate cac2, ccadb_certificate cc2
			WHERE cac.CERTIFICATE_ID = certificateID
				AND cac.CA_ID = cac2.CA_ID
				AND EXISTS (
					SELECT 1
						FROM certificate c, ca_trust_purpose ctp
						WHERE c.ID = cac2.CERTIFICATE_ID
							AND x509_notAfter(c.CERTIFICATE) > statement_timestamp() AT TIME ZONE 'UTC'
							AND c.ISSUER_CA_ID = ctp.CA_ID
							AND ctp.TRUST_CONTEXT_ID = trustContextID
							AND ctp.TRUST_PURPOSE_ID = 1
							AND NOT ctp.ALL_CHAINS_REVOKED_IN_SALESFORCE
							AND ctp.IS_TIME_VALID
				)
				AND cac2.CERTIFICATE_ID = cc2.CERTIFICATE_ID
				AND cc2.CCADB_RECORD_ID IS NOT NULL;	-- Ignore CA certificates not in CCADB (e.g., kernel mode cross-certificates).
		IF FOUND THEN
			IF t_url1 != t_url2 THEN
				t_problems := array_append(t_problems, '"BR Audit" URLs: ' || t_url1 || ' != ' || t_url2);
			END IF;
			IF t_type1 != t_type2 THEN
				t_problems := array_append(t_problems, '"BR Audit Type"s inconsistent: ' || t_type1 || ' != ' || t_type2);
			END IF;
			IF t_date1 != t_date2 THEN
				t_problems := array_append(t_problems, '"BR Audit Statement Date"s: ' || t_date1 || ' != ' || t_date2);
			END IF;
			IF t_start1 != t_start2 THEN
				t_problems := array_append(t_problems, '"BR Audit Period Start Date"s: ' || t_start1 || ' != ' || t_start2);
			END IF;
			IF t_end1 != t_end2 THEN
				t_problems := array_append(t_problems, '"BR Audit Period End Date"s: ' || t_end1 || ' != ' || t_end2);
			END IF;
		END IF;

		SELECT min(coalesce(cc2.EVSSL_AUDIT_URL, '&lt;omitted&gt;')), max(coalesce(cc2.EVSSL_AUDIT_URL, '&lt;omitted&gt;')),
				min(coalesce(cc2.EVSSL_AUDIT_TYPE, '&lt;omitted&gt;')), max(coalesce(cc2.EVSSL_AUDIT_TYPE, '&lt;omitted&gt;')),
				min(coalesce(cc2.EVSSL_AUDIT_DATE::text, '&lt;omitted&gt;')), max(coalesce(cc2.EVSSL_AUDIT_DATE::text, '&lt;omitted&gt;')),
				min(coalesce(cc2.EVSSL_AUDIT_START::text, '&lt;omitted&gt;')), max(coalesce(cc2.EVSSL_AUDIT_START::text, '&lt;omitted&gt;')),
				min(coalesce(cc2.EVSSL_AUDIT_END::text, '&lt;omitted&gt;')), max(coalesce(cc2.EVSSL_AUDIT_END::text, '&lt;omitted&gt;'))
			INTO t_url1, t_url2,
				t_type1, t_type2,
				t_date1, t_date2,
				t_start1, t_start2,
				t_end1, t_end2
			FROM ca_certificate cac, ca_certificate cac2, ccadb_certificate cc2
			WHERE cac.CERTIFICATE_ID = certificateID
				AND cac.CA_ID = cac2.CA_ID
				AND EXISTS (
					SELECT 1
						FROM certificate c, ca_trust_purpose ctp
						WHERE c.ID = cac2.CERTIFICATE_ID
							AND x509_notAfter(c.CERTIFICATE) > statement_timestamp() AT TIME ZONE 'UTC'
							AND c.ISSUER_CA_ID = ctp.CA_ID
							AND ctp.TRUST_CONTEXT_ID = trustContextID
							AND ctp.TRUST_PURPOSE_ID >= 100
							AND NOT ctp.ALL_CHAINS_REVOKED_IN_SALESFORCE
							AND ctp.IS_TIME_VALID
				)
				AND cac2.CERTIFICATE_ID = cc2.CERTIFICATE_ID
				AND cc2.CCADB_RECORD_ID IS NOT NULL;	-- Ignore CA certificates not in CCADB (e.g., kernel mode cross-certificates).
		IF FOUND THEN
			IF t_url1 != t_url2 THEN
				t_problems := array_append(t_problems, '"EV SSL Audit" URLs: ' || t_url1 || ' != ' || t_url2);
			END IF;
			IF t_type1 != t_type2 THEN
				t_problems := array_append(t_problems, '"EV SSL Audit Type"s: ' || t_type1 || ' != ' || t_type2);
			END IF;
			IF t_date1 != t_date2 THEN
				t_problems := array_append(t_problems, '"EV SSL Audit Statement Date"s: ' || t_date1 || ' != ' || t_date2);
			END IF;
			IF t_start1 != t_start2 THEN
				t_problems := array_append(t_problems, '"EV SSL Audit Period Start Date"s: ' || t_start1 || ' != ' || t_start2);
			END IF;
			IF t_end1 != t_end2 THEN
				t_problems := array_append(t_problems, '"EV SSL Audit Period End Date"s: ' || t_end1 || ' != ' || t_end2);
			END IF;
		END IF;

	ELSIF t_disclosureStatus = 'DisclosedWithInconsistentCPS' THEN
		SELECT min(coalesce(cc2.CP_URL, '&lt;omitted&gt;')), max(coalesce(cc2.CP_URL, '&lt;omitted&gt;')),
				min(coalesce(cc2.CPS_URL, '&lt;omitted&gt;')), max(coalesce(cc2.CPS_URL, '&lt;omitted&gt;'))
			INTO t_url1, t_url2,
				t_type1, t_type2
			FROM ca_certificate cac, ca_certificate cac2, ccadb_certificate cc2
			WHERE cac.CERTIFICATE_ID = certificateID
				AND cac.CA_ID = cac2.CA_ID
				AND EXISTS (
					SELECT 1
						FROM certificate c, ca_trust_purpose ctp
						WHERE c.ID = cac2.CERTIFICATE_ID
							AND x509_notAfter(c.CERTIFICATE) > statement_timestamp() AT TIME ZONE 'UTC'
							AND c.ISSUER_CA_ID = ctp.CA_ID
							AND ctp.TRUST_CONTEXT_ID = trustContextID
							AND NOT ctp.ALL_CHAINS_REVOKED_IN_SALESFORCE
							AND ctp.IS_TIME_VALID
				)
				AND cac2.CERTIFICATE_ID = cc2.CERTIFICATE_ID
				AND cc2.CCADB_RECORD_ID IS NOT NULL;	-- Ignore CA certificates not in CCADB (e.g., kernel mode cross-certificates).
		IF t_url1 != t_url2 THEN
			t_problems := array_append(t_problems, '"Certificate Policy (CP)" URLs: ' || t_url1 || ' != ' || t_url2);
		END IF;
		IF t_type1 != t_type2 THEN
			t_problems := array_append(t_problems, '"Certification Practice Statement (CPS)" URLs: ' || t_type1 || ' != ' || t_type2);
		END IF;

	END IF;

	RETURN t_problems;
END;
$$ LANGUAGE plpgsql;
