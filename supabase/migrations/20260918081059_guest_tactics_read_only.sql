-- QR participation grants reading published tactics, not the KDR role.
-- Keep existing drawings and the read RPC unchanged.
revoke execute on function public.external_tactical_write(text,jsonb,uuid[]) from public,anon,authenticated;
