SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger:  ntrPOHeaderUpdate                                          */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  PO Header Update trigger                                   */  
/*                                                                      */  
/* Input Parameters:                                                    */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 12-Nov-2002  Ricky     Include changes from SOS Oct 1st-Oct 31th By  */  
/*                        Ricky                                         */  
/* 21-Apr-2003  June      TBL HK - FBR10621                             */  
/* 26-Apr-2003  YokeBeen  Modified TransmitLogKey2 for IDSHK TBL        */  
/* 12-Jun-2003  Shong     Performance Tuning - Changing a logic when    */  
/*                        insert into Transmitlog (TBL interface)       */  
/* 02-Dec-2004  Wally     Changes done by HK local IT (SOS27580)        */  
/* 29-Mar-2005  Shong     Performance Tuning                            */  
/* 18-Apr-2005  MaryVong  Check-in for Shong's changes (SOS34015)       */  
/* 15-Aug-2005  June      SOS39407 - Update POdetail.ExternPOkey        */  
/* 13-Oct-2005  Ong       SOS41855 - No TBLPOCLOSE transmitlog when     */  
/*                        PO.OpenQty <> 0                               */  
/* 07-Aug-2006  Vicky     SOS#55884 - Insert into Transmitlog3 when     */  
/*                        PO.ExternStatus is closed                     */  
/* 04-Oct-2006  Shong     Add Loop for Insert Transmitlog3              */  
/*                        And do not reverse the status back to 0       */  
/* 29-May-2008  YokeBeen  SOS#107041 - New trigger point upon PO.Status */  
/*                        to be updated to '1' for PO Outbound with     */  
/*                        StorerConfig.ConfigKey = 'POPreITF'.          */  
/*                        - (YokeBeen01)                                */  
/* 11-Nov-2010  TLTING    SOS195797 - Check detail qty for auto close PO*/  
/* 21-Feb-2011            SOS195797 - add checking sum(qtyreceived) >0  */  
/*                        (tlting01)                                    */  
/* 01-Aug-2011  SPChin    SOS222461 - Bug Fixed                         */  
/* 24-May-2012  TLTING01  DM Integrity issue - Update editdate for      */  
/*                         status < '9'                                 */  
/* 28-Oct-2013  TLTING     Review Editdate column update                */  
/* 28-Jan-2017  TLTING     Set Option                                   */  
/*----------------------------------------------------------------------*/  
/* 22-Feb-2019  YokeBeen  WMS8093 - Adding new trigger point with setup */  
/*                        using ITFTriggerConfig.                       */  
/*                        - Moved existing trigger points to perform in */  
/*                          sub-sp isp_ITF_ntrPO. - (YokeBeen02)        */  
/* 24-May-2023  WLChooi   WMS-22565 - Enhance UPDATEEXTPO (WL01)        */
/************************************************************************/  
  
CREATE   TRIGGER [dbo].[ntrPOHeaderUpdate]  
ON  [dbo].[PO]  
FOR UPDATE  
AS  
BEGIN  
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END  
  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF     
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE  
           @b_Success               int       -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err                   int       -- Error number returned by stored procedure or this trigger  
         , @n_err2                  int       -- For Additional Error Detection  
         , @c_errmsg                NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
         , @n_continue              int  
         , @n_starttcnt             int       -- Holds the current transaction count  
         , @c_preprocess            NVARCHAR(250) -- preprocess  
         , @c_pstprocess            NVARCHAR(250) -- post process  
         , @n_cnt                   int  
         , @c_trmlogkey             NVARCHAR(10)  
         , @c_pokey                 NVARCHAR(10)  
         , @c_Storerkey             NVARCHAR(15)    -- added fro idsv5 by June 21.Jun.02  
         , @c_authority             NVARCHAR(1)     -- added for idsv5 by June 21.Jun.02  
         , @c_extpo                 NVARCHAR(1)     -- added by Vicky 18 Apr 2003 - for TBLHK  
         , @n_PO_OpenQty            int             -- SOS41855  
         , @c_pologitf              NVARCHAR(1)     -- SOS#55884  
         , @c_instorerkey           NVARCHAR(15)    -- SOS#55884  
         , @c_inspokey              NVARCHAR(10)    -- SOS#55884  
         , @c_POpreITF              NVARCHAR(1)     -- (YokeBeen01)  
         , @c_StatusUpdated         NVARCHAR(1)     -- (YokeBeen02)   
         , @c_ExternStatusUpdated   NVARCHAR(1)     -- (YokeBeen02)   
         , @c_Proceed               NVARCHAR(1)     -- (YokeBeen02)  
         , @c_COLUMN_NAME           VARCHAR(50)     -- (YokeBeen02)   
         , @c_ColumnsUpdated        VARCHAR(1000)   -- (YokeBeen02)  
         , @b_ColumnsUpdated        VARBINARY(1000) -- (YokeBeen02) 
         , @c_Option1               NVARCHAR(50) = ''   --WL01
         , @c_Option2               NVARCHAR(50) = ''   --WL01
         , @c_Option3               NVARCHAR(50) = ''   --WL01
         , @c_Option4               NVARCHAR(50) = ''   --WL01
         , @c_Option5               NVARCHAR(MAX) = ''  --WL01
         , @c_IncludePOType         NVARCHAR(1000)  --WL01
         , @c_POType                NVARCHAR(50)    --WL01
         , @c_NoUPDATEEXTPO         NVARCHAR(10) = ''   --WL01
  
   SET @c_StatusUpdated = 'N'                -- (YokeBeen02)  
   SET @c_ExternStatusUpdated = 'N'          -- (YokeBeen02)  
   SET @c_Proceed = 'N'                      -- (YokeBeen02)  
   SET @b_ColumnsUpdated = COLUMNS_UPDATED() -- (YokeBeen02)  
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
  
   IF UPDATE(ArchiveCop)  
   BEGIN  
      SELECT @n_continue = 4  
   END  
     
   -- tlting02  
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED  
                WHERE INSERTED.POKey = DELETED.POKey  
                AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) )   
         AND ( @n_continue=1 OR @n_continue=2 )  
         AND NOT UPDATE(EditDate)  
   BEGIN  
      UPDATE PO WITH (ROWLOCK)  
         SET EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop = NULL  
         FROM PO, INSERTED  
         WHERE PO.POKey = INSERTED.POKey  
         AND PO.[status] < '9'   
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63816     
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))   
                         + ': Update Failed On Table PO. (ntrPOHeaderUpdate)' + ' ( '   
                           + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
      END  
   END  
     
   IF UPDATE(TrafficCop)  
   BEGIN  
      SELECT @n_continue = 4  
   END  
  
   /* #INCLUDE <TRPOHU1.SQL> */  
  
   IF UPDATE(EXTERNSTATUS)  
   BEGIN  
      /* -- (YokeBeen02) - Start  
      -- (YokeBeen01) - Start  
      DECLARE C_PO_ITF_RECORDS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT INSERTED.Storerkey,  
              INSERTED.POKey  
         FROM INSERTED  
        WHERE INSERTED.ExternStatus = '1'  
  
      OPEN C_PO_ITF_RECORDS  
  
      FETCH NEXT FROM C_PO_ITF_RECORDS INTO @c_instorerkey, @c_inspokey  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         -- if PO.status = '1'  
         IF EXISTS (SELECT 1 FROM PO WITH (NOLOCK) WHERE POKey = @c_inspokey AND ExternStatus = '1')  
         BEGIN  
            -- Insert into Transmitlog3 when PO.ExternStatus = '1'  
            SELECT @b_success = 0  
            EXECUTE nspGetRight NULL,  -- facility  
                    @c_instorerkey,    -- Storerkey  
                    NULL,              -- Sku  
                   'POPreITF',         -- Configkey  
                    @b_success    output,  
                    @c_POpreITF   output,  
                    @n_err        output,  
                    @c_errmsg     output  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'ntrPOHeaderUpdate' + ISNULL(dbo.fnc_RTrim(@c_errmsg),'')  
            END  
            ELSE IF @c_POpreITF = '1'  
            BEGIN  
               SELECT @b_success = 1  
               EXEC dbo.ispGenTransmitLog3 'POPREREQ', @c_inspokey, '', @c_instorerkey, ''  
                                          , @b_success OUTPUT  
                                          , @n_err OUTPUT  
                                          , @c_errmsg OUTPUT  
  
               IF @b_success <> 1  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63810  
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
                                   + ': Unable to obtain transmitlogkey (ntrPOHeaderUpdate)' + ' ( '  
                                   + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
               END  
            END -- Insert into Transmitlog3 when PO.ExternStatus = '1'  
         END  
  
         FETCH NEXT FROM C_PO_ITF_RECORDS INTO @c_instorerkey, @c_inspokey  
      END -- While  
      CLOSE C_PO_ITF_RECORDS  
      DEALLOCATE C_PO_ITF_RECORDS  
      -- (YokeBeen01) - End  
      -- (YokeBeen02) - End */  
  
      -- if manually close, update status to '9'  
      -- SOS#55884 (Begin)  
      DECLARE C_PO_INSERT_RECORDS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT INSERTED.Storerkey,  
              INSERTED.POKey  
         FROM INSERTED  
        WHERE INSERTED.ExternStatus = '9'  
  
      -- SOS#55884 (End)  
  
      OPEN C_PO_INSERT_RECORDS  
      FETCH NEXT FROM C_PO_INSERT_RECORDS INTO @c_instorerkey, @c_inspokey  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF EXISTS (SELECT 1 FROM PO WITH (NOLOCK) WHERE POKEY = @c_inspokey AND status < '9' AND externstatus = '9' )  
         BEGIN  
            SET @c_StatusUpdated = 'Y' -- (YokeBeen02)  
  
            UPDATE PO WITH (ROWLOCK)  
               SET status = '9',  
                   trafficcop = NULL  
             WHERE POKEY = @c_inspokey  
               AND Externstatus = '9'  
  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63811  
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
                                + ': Update Failed On Table PO. (ntrPOHeaderUpdate) ( '  
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
            END  
         END  
  
         /* -- (YokeBeen02) - Start  
         -- SOS#55884 - Insert into Transmitlog3 when PO.ExternStatus is closed (Start)  
         SELECT @b_success = 0  
         EXECUTE nspGetRight NULL,  -- facility  
                 @c_instorerkey,  -- Storerkey  
                 NULL,            -- Sku  
                'POLOG',         -- Configkey  
                 @b_success    output,  
                 @c_pologitf   output,  
                 @n_err        output,  
                 @c_errmsg     output  
  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3, @c_errmsg = 'ntrPOHeaderUpdate' + ISNULL(dbo.fnc_RTrim(@c_errmsg),'')  
         END  
         ELSE IF @c_pologitf = '1'  
         BEGIN  
            SELECT @b_success = 1  
            EXEC ispGenTransmitLog3 'POLOG', @c_inspokey, '', @c_instorerkey, ''  
                                   , @b_success OUTPUT  
                                   , @n_err OUTPUT  
                                   , @c_errmsg OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63812  
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
                                + ': Unable to obtain transmitlogkey (ntrPOHeaderUpdate)' + ' ( '  
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
            END  
         END -- SOS#55884 - Insert into Transmitlog3 when PO.ExternStatus is closed (End)  
         -- (YokeBeen02) - Start */  
         FETCH NEXT FROM C_PO_INSERT_RECORDS INTO @c_instorerkey, @c_inspokey  
      END -- While  
      CLOSE C_PO_INSERT_RECORDS  
      DEALLOCATE C_PO_INSERT_RECORDS  
   END -- IF UPDATE(EXTERNSTATUS)  
  
   -- Start : SOS39407  
   IF UPDATE(ExternPOkey)  
   BEGIN  
      UPDATE PODetail WITH (ROWLOCK)  
         SET ExternPokey = INSERTED.ExternPOkey,  
             Trafficcop = NULL,  
             EditDate = GETDATE(),   --tlting  
             EditWho = SUSER_SNAME()  
        FROM PODetail, INSERTED, DELETED  
       WHERE PODetail.Pokey = INSERTED.POKey  
         AND INSERTED.POKEY = DELETED.POkey  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63813  
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
                          + ': Update Failed On Table PODetail. (ntrPOHeaderUpdate)' + ' ( '  
                          + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
      END  
   END  
   -- End : SOS39407  
  
--    -- Added By SHONG  
--    -- Spec From Thailand  
--    -- Not Allow to Modify PO When Extern Status = 9 or CLOSED  
--    -- Date: 05th Dec 2000  
--    IF @n_continue=1 or @n_continue=2  
--    BEGIN  
--       IF EXISTS(SELECT POKEY FROM DELETED WHERE ExternStatus = "9")  
--       BEGIN  
--          SELECT @n_continue = 3  
--          SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63814  
--          SELECT @c_errmsg="NSQL"+CONVERT(char(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
--                          +": PO Cannot be Modified, Status = CLOSED. (ntrPOHeaderUpdate)" + " ( "  
--                          + " SQLSvr MESSAGE=" + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + " ) "  
--       END  
--    END  
--    -- End of Modify  
  
   IF ( @n_continue = 1 OR @n_continue=2 ) AND NOT UPDATE(EditDate)  
   BEGIN  
      UPDATE PO WITH (ROWLOCK)  
         SET EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop = NULL  
        FROM PO, INSERTED, DELETED  
       WHERE PO.POKey = INSERTED.POKey  
         AND PO.POKey = DELETED.POKey  
         AND INSERTED.POKey = DELETED.POKey  
         AND PO.STATUS = '9'        -- tlting02  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63815  
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
                          + ': Update Failed On Table PO. (ntrPOHeaderUpdate)' + ' ( '  
                          + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
      END  
   END  
  
--    IF @n_continue = 1 or @n_continue=2  
--    BEGIN  
--       UPDATE PO SET  Status = "0", ExternStatus = "0"  
--         FROM PO, INSERTED, DELETED  
--        WHERE PO.POKey = INSERTED.POKey AND INSERTED.POKey = DELETED.POKey  
--          AND INSERTED.OpenQty > 0 AND DELETED.Status = "9"  
--  
--       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
--       IF @n_err <> 0  
--       BEGIN  
--          SELECT @n_continue = 3  
--          SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63816  
--          SELECT @c_errmsg="NSQL"+CONVERT(char(5),ISNULL(dbo.fnc_RTrim(@n_err),0))+": Update Failed On Table PO. (ntrPOHeaderUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
--       END  
--    END  
  
   IF @n_continue = 1 or @n_continue=2  
   BEGIN  
--    UPDATE PO WITH (ROWLOCK)  
--    SET  Status = "9",  
--            PO.ExternStatus="9" -- Added By Shong For PO Automate, Date: 6th Dec 2000  
--    FROM PO,  
--    INSERTED,  
--    DELETED  
--    WHERE PO.POKey = INSERTED.POKey  
--    AND PO.OpenQty = 0  
--    AND INSERTED.Openqty = 0  
--    AND INSERTED.POKey = DELETED.POKey  
--    added by wally 18.oct.2001  
--    IDSHK sos 2023: to handle po with zero qty on both ordered and received column  
  
      /* Added By Vicky 18 Apr 2003 - For TBLHK */  
      /* Only close PO Extern Status automatically when 'UPDATEEXTPO' flag is turn on */  
      DECLARE PO_UPD_CURSOR CURSOR READ_ONLY FAST_FORWARD FOR  
       SELECT StorerKey, POKey  
             ,OpenQty -- SOS41855  
         FROM INSERTED  
  
      OPEN PO_UPD_CURSOR  
  
      FETCH NEXT FROM PO_UPD_CURSOR INTO @c_Storerkey, @c_POKey, @n_PO_OpenQty -- SOS41855  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SELECT @b_success = 0  
  
         EXECUTE nspGetRight NULL,  -- facility  
                 @c_StorerKey,      -- Storerkey  
                 NULL,              -- Sku  
                'UPDATEEXTPO',      -- Configkey  
                 @b_success    output,  
                 @c_extpo      output,  
                 @n_err        output,  
                 @c_errmsg     output,
                 @c_Option1    OUTPUT,  --WL01
                 @c_Option2    OUTPUT,  --WL01
                 @c_Option3    OUTPUT,  --WL01
                 @c_Option4    OUTPUT,  --WL01
                 @c_Option5    OUTPUT   --WL01
  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3, @c_errmsg = 'ntrPOHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)  
         END  
         ELSE IF @c_extpo = '1'  
         BEGIN  
            --WL01 S
            SET @c_NoUPDATEEXTPO = ''

            IF ISNULL(@c_Option5,'') <> ''
            BEGIN
               SELECT @c_IncludePOType = dbo.fnc_GetParamValueFromString('@c_IncludePOType', @c_Option5, @c_IncludePOType) 

               IF ISNULL(@c_IncludePOType,'') <> ''
               BEGIN
                  SELECT @c_POType = POType
                  FROM Inserted
                  WHERE POKey = @c_POKey

                  IF NOT EXISTS ( SELECT 1
                                  FROM dbo.fnc_DelimSplit(',', @c_IncludePOType) FDS 
                                  WHERE FDS.ColValue = @c_POType)
                  BEGIN
                     SET @c_NoUPDATEEXTPO = 'Y'
                  END
               END
            END
            --WL01 E

               -- tlting01  
            IF NOT EXISTS ( SELECT 1 FROM  PODETAIL WITH (NOLOCK)  
                 WHERE PODETAIL.pokey = @c_POKey  
                 AND   PODETAIL.QtyOrdered > PODETAIL.QtyReceived )  
                 --AND (SELECT SUM(qtyreceived)  --SOS222461  
                 AND (SELECT SUM(CAST(qtyreceived AS BIGINT))  --SOS222461  
                 FROM  PODETAIL WITH (NOLOCK)  
                 WHERE PODETAIL.pokey = @c_POKey ) > 0 AND ISNULL(@c_NoUPDATEEXTPO,'') = ''   --WL01
--            (SELECT SUM(qtyreceived)  
--                  FROM  PODETAIL WITH (NOLOCK)  
--                 WHERE PODETAIL.pokey = @c_POKey ) > 0  
--                   AND @n_PO_OpenQty <= 0  -- SOS41855  
            BEGIN  
               SET @c_StatusUpdated = 'Y'       -- (YokeBeen02)  
               SET @c_ExternStatusUpdated = 'Y' -- (YokeBeen02)  
               
               UPDATE PO WITH (ROWLOCK)  
               SET status = '9', externstatus = '9'
               WHERE POKey = @c_POKey  
  
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63817  
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
                                   + ': Update Failed On Table PO. (ntrPOHeaderUpdate)' + ' ( '  
                                   + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
               END
            END  
         END -- IF @c_extpo = '1'  
  
         -- Added for IDSV5 by June 21.Jun.02, (extract from IDSTHAI) *** Start  
         IF @n_continue=1 OR @n_continue=2  
         BEGIN  
            SELECT @b_success = 0  
            EXECUTE nspGetRight NULL,  -- facility  
                    @c_StorerKey,    -- Storerkey  
                    NULL,            -- Sku  
                   'POITF',         -- Configkey  
                    @b_success    output,  
                    @c_authority  output,  
                    @n_err        output,  
                    @c_errmsg     output  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'ntrPOHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)  
            END  
            ELSE IF @c_authority = '1'  
            BEGIN  
               -- insert into transmitlog table when PO status = '9' (openqty = 0) or Externstatus = '9' (Closed manually)  
               IF EXISTS (SELECT 1 FROM PO WITH (NOLOCK), INSERTED, DELETED  
                           WHERE PO.Pokey = INSERTED.POKey  
                             AND INSERTED.POKEY = DELETED.POkey  
                             AND ( ( INSERTED.OpenQty <= 0  
                             AND DELETED.Openqty > 0 )  
                              OR INSERTED.Externstatus = '9' )  
                             AND PO.Pokey = @c_pokey )  
                             --AND PO.Pokey NOT IN (SELECT Key1 from transmitlog where tablename = 'PO'))  
               BEGIN  
                  IF NOT EXISTS(SELECT 1 FROM Transmitlog WITH (NOLOCK) WHERE tablename = 'PO' AND Key1 = @c_pokey)  
                  BEGIN  
                     SELECT @b_success = 1  
                     EXECUTE nspg_getkey  
                            'transmitlogkey'  
                           , 10  
                           , @c_trmlogkey OUTPUT  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT  
  
                     IF NOT @b_success = 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63818  
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
                                         + ': Unable to Obtain transmitlogkey. (ntrPOHeaderUpdate)' + ' ( '  
                                         + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
                     END  
                     ELSE  
                     BEGIN  
                        INSERT INTO transmitlog (transmitlogkey, tablename, key1, transmitflag)  
                        VALUES (@c_trmlogkey, 'PO', @c_POkey , '0')  
                     END  
                  END -- Not exists  
               END  
            END  
         END -- Added for IDSV5 by June 21.Jun.02, (extract from IDSTHAI) *** End  
  
         -- Start IDSHK TBL - Outbound PIX Export  
         -- Added by June 11.APR.2003  
         -- Modify By SHONG on 12-JUN-2003 for Performance Tuning  
         IF @n_continue=1 OR @n_continue=2  
         BEGIN  
            DECLARE  @c_TBLHKITF NVARCHAR(1)  
  
            -- insert into transmitlog2 table when PO status = '9' (openqty = 0) or Externstatus = '9' (Closed manually)  
            SELECT @c_TBLHKITF = 0  
            EXECUTE nspGetRight NULL,  -- facility  
                    @c_storerkey,      -- Storerkey  
                    NULL,              -- Sku  
                   'TBLHKITF',         -- Configkey  
                    @b_success output,  
                    @c_TBLHKITF output,  
                    @n_err output,  
                    @c_errmsg output  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = 'ntrPOHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)  
            END  
            ELSE IF @c_TBLHKITF = '1'  
            BEGIN  
               IF EXISTS (SELECT 1 FROM PO WITH (NOLOCK)  
                            JOIN INSERTED ON (PO.Pokey = INSERTED.POKey)  
                            JOIN DELETED ON (INSERTED.POKEY = DELETED.POkey)  
                            JOIN PODETAIL WITH (NOLOCK) ON (PO.Pokey = PODETAIL.Pokey)  
                            JOIN RECEIPTDETAIL WITH (NOLOCK) ON (PO.Pokey = RECEIPTDETAIL.POKEY)  
                            JOIN LOC WITH (NOLOCK) ON (RECEIPTDETAIL.TOLOC = LOC.LOC)  
                            LEFT OUTER JOIN ID WITH (NOLOCK) ON (RECEIPTDETAIL.TOID = ID.ID)  
                           WHERE (( INSERTED.OpenQty <= 0 AND DELETED.Openqty > 0 )  OR INSERTED.Externstatus = '9' )  
                           -- AND PO.Pokey NOT IN (SELECT Key1 FROM transmitlog2 where tablename = 'TBLPOCLOSE')  
                             AND PO.POKey = @c_pokey  
                             AND (LOC.LOCATIONFLAG = 'HOLD' OR LOC.LOCATIONFLAG = 'DAMAGED'OR ID.STATUS = 'HOLD'))  
               BEGIN  
                  IF NOT EXISTS(SELECT 1 FROM Transmitlog2 WITH (NOLOCK)  
                                        WHERE tablename = 'TBLPOCLOSE' AND Key1 = @c_pokey)  
                  BEGIN  
                     SELECT @b_success = 1  
                     EXECUTE nspg_getkey  
                            'transmitlogkey2'    -- Modified by YokeBeen on 26-Apr-2003  
                           , 10  
                           , @c_trmlogkey output  
                           , @b_success output  
                           , @n_err output  
                           , @c_errmsg output  
  
                     IF NOT @b_success = 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63819  
                        SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
                                         + ': Unable To Obtain Transmitlogkey. (ntrReceiptHeaderUpdate)' + ' ( '  
                                         + ' sqlsvr message=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
                     END  
                     ELSE  
                     BEGIN  
                        INSERT transmitlog2 (transmitlogkey, tablename, key1, transmitflag)  
                        VALUES (@c_trmlogkey, 'TBLPOCLOSE', @c_pokey, '0')  
                     END  
                  END -- Not exist in Transmitlog2  
               END -- TBLHKITF  
               ELSE -- SOS 27580 :Normal Goods Received in Normal Location (Interface Changes)  
               BEGIN  
                  IF EXISTS (SELECT 1 FROM PO WITH (NOLOCK)  
                               JOIN INSERTED ON (PO.Pokey = INSERTED.POKey)  
                               JOIN DELETED ON (INSERTED.POKEY = DELETED.POkey)  
                               JOIN PODETAIL WITH (NOLOCK) ON (PO.Pokey = PODETAIL.Pokey)  
                               JOIN RECEIPTDETAIL WITH (NOLOCK) ON (PO.Pokey = RECEIPTDETAIL.POKEY)  
                               JOIN LOC WITH (NOLOCK) ON (RECEIPTDETAIL.TOLOC = LOC.LOC)  
                               LEFT OUTER JOIN ID WITH (NOLOCK) ON (RECEIPTDETAIL.TOID = ID.ID)  
                              WHERE (( INSERTED.OpenQty <= 0 AND DELETED.Openqty > 0 )  OR INSERTED.Externstatus = '9' )  
                               -- AND PO.Pokey NOT IN (SELECT Key1 FROM transmitlog2 where tablename = 'TBLPOCLOSE')  
                                AND PO.POKey = @c_pokey  
                                AND LOC.LOCATIONFLAG <> 'HOLD'  
                                AND LOC.LOCATIONFLAG <> 'DAMAGED'  
                                AND LOC.Status = 'OK')  
                  BEGIN  
                     IF NOT EXISTS (SELECT 1 FROM Transmitlog2 WITH (NOLOCK)  
                                     WHERE tablename = 'TBLPOCLOSE' AND Key1 = @c_pokey)  
                     BEGIN  
                        SELECT @b_success = 1  
                        EXECUTE nspg_getkey  
                               'TRANSMITLOGKEY2'    -- Modified by YokeBeen on 26-Apr-2003  
                              , 10  
                              , @c_trmlogkey output  
                              , @b_success output  
                              , @n_err output  
                              , @c_errmsg output  
  
                        IF NOT @b_success = 1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(dbo.fnc_RTrim(@n_err),0)), @n_err=63820  
                           SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))  
                                            + ': Unable To Obtain Transmitlogkey. (ntrReceiptHeaderUpdate)' + ' ( '  
                                            + ' sqlsvr message=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
                        END  
                        ELSE  
                        BEGIN  
                           INSERT transmitlog2 (transmitlogkey, tablename, key1, transmitflag)  
                           VALUES (@c_trmlogkey, 'TBLPOCLOSE', @c_pokey, '0')  
                        END  
                     END -- Not exists in Trnsmitlog2 table  
                  END  
               END -- ELSE -- SOS 27580 :Normal Goods Received in Normal Location (Interface Changes)  
            END  
         END  
         -- End IDSHK TBL - Outbound PIX Export  
         /* End TBLHK*/  
  
         FETCH NEXT FROM PO_UPD_CURSOR INTO @c_Storerkey, @c_POKey, @n_PO_OpenQty -- SOS41855  
      END -- While  
      CLOSE PO_UPD_CURSOR  
      DEALLOCATE PO_UPD_CURSOR  
   END -- IF @n_continue = 1 or @n_continue=2  
  
/********************************************************/    
/* Interface Trigger Points Calling Process - (Start)   */    
/********************************************************/    
   IF @n_continue = 1 OR @n_continue = 2     
   BEGIN    
      DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      SELECT DISTINCT INSERTED.POKey, INSERTED.StorerKey  
      FROM   INSERTED   
      JOIN   PO WITH (NOLOCK) ON (INSERTED.POKey = PO.POKey)  
  
      OPEN Cur_TriggerPoints    
      FETCH NEXT FROM Cur_TriggerPoints INTO @c_POKey, @c_Storerkey  
  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN  
         SET @c_Proceed = 'N'  
  
         IF EXISTS ( SELECT 1   
                     FROM  ITFTriggerConfig ITFTriggerConfig WITH (NOLOCK)         
                     WHERE ITFTriggerConfig.StorerKey   = @c_Storerkey  
                     AND   ITFTriggerConfig.SourceTable = 'PO'    
                     AND   ITFTriggerConfig.sValue      = '1' )  
         BEGIN  
            SET @c_Proceed = 'Y'             
         END  
  
         IF @c_Proceed = 'Y'  
         BEGIN  
            SET @c_ColumnsUpdated = ''      
  
            DECLARE Cur_ColUpdated CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
            SELECT COLUMN_NAME FROM dbo.fnc_GetUpdatedColumns('PO', @b_ColumnsUpdated)   
  
            OPEN Cur_ColUpdated    
            FETCH NEXT FROM Cur_ColUpdated INTO @c_COLUMN_NAME  
            WHILE @@FETCH_STATUS <> -1    
            BEGIN    
               IF @c_ColumnsUpdated = ''  
               BEGIN  
                  SET @c_ColumnsUpdated = @c_COLUMN_NAME  
               END  
               ELSE  
               BEGIN  
                  SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + @c_COLUMN_NAME  
               END  
  
               FETCH NEXT FROM Cur_ColUpdated INTO @c_COLUMN_NAME  
            END -- WHILE @@FETCH_STATUS <> -1    
            CLOSE Cur_ColUpdated    
            DEALLOCATE Cur_ColUpdated    
  
            IF @c_StatusUpdated = 'Y'   
            BEGIN  
               IF @c_ColumnsUpdated = ''  
               BEGIN  
                  SET @c_ColumnsUpdated = 'STATUS'  
               END  
               ELSE  
               BEGIN  
                  SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + 'STATUS'  
               END  
            END  
  
            IF @c_ExternStatusUpdated = 'Y'   
            BEGIN  
               IF @c_ColumnsUpdated = ''  
               BEGIN  
                  SET @c_ColumnsUpdated = 'EXTERNSTATUS'  
               END  
               ELSE  
               BEGIN  
                  SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + 'EXTERNSTATUS'  
               END  
            END  
  
            EXECUTE dbo.isp_ITF_ntrPO    
                       @c_TriggerName    = 'ntrPOHeaderUpdate'  
                     , @c_SourceTable    = 'PO'    
                     , @c_Storerkey      = @c_Storerkey  
                     , @c_POKey          = @c_POKey    
                     , @c_ColumnsUpdated = @c_ColumnsUpdated                             
                     , @b_Success        = @b_Success   OUTPUT    
                     , @n_err            = @n_err       OUTPUT    
                     , @c_errmsg         = @c_errmsg    OUTPUT   
         END  
  
         FETCH NEXT FROM Cur_TriggerPoints INTO @c_POKey, @c_Storerkey  
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE Cur_TriggerPoints    
      DEALLOCATE Cur_TriggerPoints   
   END -- IF @n_continue = 1 OR @n_continue = 2     
/********************************************************/    
/* Interface Trigger Points Calling Process - (End)     */    
/********************************************************/    
  
   /* #INCLUDE <TRPOHU2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPOHeaderUpdate'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END -- End trigger  

GO