SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ntrReceiptHeaderAdd                                 */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: normal receipt                                              */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures OR triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* PVCS Version: 2.3                                                   */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2002-08-05 1.0  admin    Initial revision                            */
/* 2002-08-26 1.1  wkloo    SOS #7684 - the running no for              */
/*                          CarrierReferenceNo is not working           */
/* 2002-12-11 1.2  ryee     Changes for IDSTH V5 Upgrade                */
/* 2002-12-30 1.3  ryee     To include the 'UPD GTH ASNkey to ExtASNkey'*/
/*                          configkey to control the generation of the  */
/*                          Externreceiptkey and PO Key                 */
/* 2003-03-17 1.4  wtshong  SOS# 6287 Do not issues RR No for Receipt   */
/*                          Type = GRN                                  */
/* 2003-06-04 1.5  ryee     Version 5.1 - To include CDC changes        */
/* 2004-02-03 1.6  ryee     To include the DocType update               */
/* 2004-06-17 1.7  mvong    IDSHK - Nuance Watson (RA Export)           */
/* 2004-06-22 1.8  mvong    SOS24373 - Add DocType ='A' for             */
/*                          RecType = 'Normal'                          */
/* 2004-10-29 1.9  wmacaraig SOS 27626 -- Nuance outbound interface     */
/*                          modification (done by local IT)             */
/* 2005-01-14 1.10 ryee     Adding of C4 FlowThru type                  */
/* 2005-06-07 1.11 ungdh    To support RDT and re-number the error code */
/* 2006-07-27 1.12 YokeBeen For Return Goods only.                      */
/*                          Set Default values for RECEIPT.RoutingTool  */
/*                          = 'Y' WHEN Configkey is either with         */
/*                          'TMSOutRtnHDR'/'TMSOutRtnDTL'and INSERTED's */
/*                          RoutingTool is NULL.                        */
/*                          Insert record into TMSLog for Interface.    */
/*                          (SOS53821) - (YokeBeen01)                   */
/* 2006-11-10 1.13 YokeBeen Remarked auto RECEIPT.RoutingTool's update. */
/*                          To add checking on this value for valid     */
/*                          records to be triggered into TMSLog.        */
/*                          All Interfaces must have the update for     */
/*                          RECEIPT.RoutingTool based on the TMS Storer */
/*                          Configkey setup in order to apply on this   */
/*                          TMS process. - (YokeBeen02)                 */
/* 2007-03-20 1.14 YokeBeen Move the TMSLog records' trigger to bottom  */
/*                          portion of this script after DocType being  */
/*                          assigned with the right values to eliminate */
/*                          miss process, when the check to carry out   */
/*                          for the Receipt.DocType of the reqest.      */
/*                          - (YokeBeen03)                              */
/* 2007-09-21 1.15 James    SOS80707 - Add 'A' as Key2 into             */
/*                          ispGenTMSLog for TMSHK                      */
/* 2008-08-27 1.16 TLTING   SQL2005 - Put fnc_RTRIM to for ISNULL Check */
/*                          (TLTING01)                                  */
/* 2009-03-17 1.17 TLTING   Change user_name() to SUSER_SNAME()         */
/* 2009-04-02 1.18 June     SOS133105 - Generic Receipt Creation        */
/*                          Interface 'RCPTADD'.                        */
/* 2009-12-23 1.19 James    Skip trigger firing if archivecop = '9'     */
/* 2015-05-12 1.20 MCTang   Enhance Generaic Trigger Interface (MC01)   */
/* 2016-04-07 1.21 NJOW01   Call custom trigger stored proc             */
/* 2016-09-21 1.22 TLTING   Change SetROWCOUNT 1 to Top 1               */
/* 2016-12-13 1.23 Leong    IN00219604 - Bug Fix.                       */
/* 2017-02-21 1.24 SPChin   IN00270982 - Bug Fixed                      */
/* 2017-06-01 1.25 TLTING02 WMS-2047 WMS2GVT Inbound events             */  
/* 2019-08-01 1.25 Wan01    WMS-9995 [CN] NIKESDC_Exceed_Hold ASN for   */
/*                          Channel                                     */
/* 2021-08-27 2.1  TLTING03 Extend ExternReceiptKey field length        */
/* 2023-01-05 2.2  Wan02    LFWM-3900 - ASN Insert into Transport Order */
/*                          DevOps Combine Script                       */
/* 2024-01-29 2.2  Wan02    UWP-14379-Implement pre-save ASN standard   */
/*                          validation check                            */
/* 2024-07-02 2.3  Inv Team UWP-17135 - Migrate Inbound Door booking    */
/************************************************************************/

CREATE   TRIGGER ntrReceiptHeaderAdd
 ON  Receipt
 FOR INSERT
 AS
-- SOS27626 (ML) 14/10/04    Nuance Outbound interface - Change to use Trnasmitlog3
 BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
 
 DECLARE  
   @b_Success           int               -- Populated by calls to stored procedures - was the proc successful?
 , @n_err               int               -- Error number returned by stored procedure OR this trigger
 , @n_err2              int               -- For Additional Error Detection
 , @c_errmsg            NVARCHAR(250)     -- Error message returned by stored procedure OR this trigger
 , @n_continue          int                 
 , @n_starttcnt         int               -- Holds the current transaction count
 , @c_preprocess        NVARCHAR(250)     -- preprocess
 , @c_pstprocess        NVARCHAR(250)     -- post process
 , @n_cnt               int  
 , @c_storerkey         NVARCHAR(15)      -- Added for IDSV5 by June 21.Jun.02 
 , @c_facility          NVARCHAR(15)      -- Added for IDSV5 by June 21.Jun.02
 , @c_authority         NVARCHAR(1)       -- Added for IDSV5 by June 21.Jun.02
 , @c_RecType           NVARCHAR(10)
 , @cReceiptKey         NVARCHAR(10)      -- (YokeBeen01)
 , @cFac_TMSInterface   NVARCHAR(1)
 , @cRoute_TMSInterface NVARCHAR(1)
 , @cRoute              NVARCHAR(10)
 , @c_COLUMN_NAME       VARCHAR(50)       -- (MC02) 
 , @c_ColumnsUpdated    VARCHAR(1000)     -- (MC02) 
 , @c_ASNStatus_From    NVARCHAR(10) = ''                                           --(Wan03)
 , @c_ASNStatus_To      NVARCHAR(10) = ''
 , @cur_ASN             CURSOR            --(Wan02-v0)

SELECT @cReceiptKey = ''      -- (YokeBeen01)


SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRRHA1.SQL> */  

-- To Skip all the trigger process when Insert the history records from Archive as user request
IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   SELECT @n_continue = 4

IF @n_continue=1 OR @n_continue=2
BEGIN    
   SELECT @c_storerkey = Storerkey, @c_facility = Facility, @cReceiptKey = ReceiptKey 
   FROM INSERTED
END

--NJOW01
IF @n_continue=1 or @n_continue=2          
BEGIN      
   IF EXISTS (SELECT 1 FROM INSERTED i   ----->Put INSERTED if INSERT action
              JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey    
              JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
              WHERE  s.configkey = 'ReceiptTrigger_SP')   -----> Current table trigger storerconfig
   BEGIN            
      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         DROP TABLE #INSERTED

       SELECT * 
       INTO #INSERTED
       FROM INSERTED
       
      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         DROP TABLE #DELETED

       SELECT * 
       INTO #DELETED
       FROM DELETED

      EXECUTE dbo.isp_ReceiptTrigger_Wrapper ----->wrapper for current table trigger
                'INSERT'  -----> @c_Action can be INSERTE, UPDATE, DELETE
              , @b_Success  OUTPUT  
              , @n_Err      OUTPUT   
              , @c_ErrMsg   OUTPUT  

      IF @b_success <> 1  
      BEGIN  
         SELECT @n_continue = 3  
               ,@c_errmsg = 'ntrReceiptHeaderAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
      END  
      
      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         DROP TABLE #INSERTED

      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         DROP TABLE #DELETED
   END
END 

--(Wan01) - START 
IF @n_continue=1 or @n_continue=2          
BEGIN    
   IF EXISTS ( SELECT 1
               FROM  INSERTED WITH (NOLOCK)
               CROSS APPLY dbo.fnc_SelectGetRight(INSERTED.Facility, INSERTED.Storerkey, '', 'ChannelInventoryMgmt') CFG
               WHERE INSERTED.HoldChannel = '1'
               AND   CFG.Authority = '0'
               )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 70010
      SET @c_errmsg  = CONVERT(char(5),@n_err)+': ASN with Channel Management turn off found'
                     + '. Disallow to hold channel. (ntrReceiptHeaderAdd)'
   END   
END
--(Wan01) - END

IF @n_Continue = 1                                                                  --(Wan02) - START
BEGIN
   SET @n_Cnt = 0
   SET @c_ASNStatus_From = ''
   SET @c_ASNStatus_To = ''

   SELECT @n_Cnt = 1
         ,@c_ASNStatus_To = i.ASNStatus
   FROM Inserted i
   OUTER APPLY dbo.fnc_GetAllowASNStatusChg(i.Facility, i.Storerkey, i.Doctype, i.Receiptkey, '', i.ASNStatus) AASC
   WHERE AASC.AllowChange = 0

   IF @n_Cnt = 1
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(CHAR(250),@n_err)
      SET @n_err=70011 --63800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Disallow to change ASNStatus from '''
                     + @c_ASNStatus_From + ''' to ''' + @c_ASNStatus_To + ''''
                     +'. (ntrReceiptHeaderAdd)'
   END
END                                                                                 --(Wan02) - END

-- Added for IDSV5 by June 21.Jun.02, (extract from IDSHK) *** Start
IF @n_continue=1 OR @n_continue=2
BEGIN    
   SELECT @b_success = 0
   Execute nspGetRight @c_facility, -- facility
             @c_StorerKey,    -- Storerkey
             null,            -- Sku
             'AutoUpdateCarrierInfo', -- Configkey
             @b_success    output,
             @c_authority  output, 
             @n_err        output,
             @c_errmsg     output
   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
      SELECT @n_err = 60151
   END
   ELSE IF @c_authority = '1'
   BEGIN
    -- Added By SHONG
    -- For OneWorld Interface
    -- begin
    -- Get Storer Configuration -- One World Interface
    -- Is One World Interface Turn On?
      UPDATE RECEIPT
      SET CarrierName  = Carrier.Company,
      CarrierAddress1 = Carrier.Address1,
      CarrierAddress2 = Carrier.Address2,
      CarrierCity = Carrier.Address3
      FROM RECEIPT
      JOIN INSERTED ON (INSERTED.ReceiptKey = RECEIPT.ReceiptKey)
      JOIN Storer AS Carrier With (NOLOCK) ON ( Carrier.StorerKey = INSERTED.CarrierKey )
--    JOIN StorerConfig WITH (NOLOCK) ON (StorerConfig.StorerKey = INSERTED.StorerKey
--    AND ConfigKey = 'OWITF' AND sValue = '1')
      WHERE (INSERTED.CarrierAddress1 IS NULL OR INSERTED.CarrierAddress1 = '')  --IN00270982
      AND   (INSERTED.CarrierAddress2 IS NULL OR INSERTED.CarrierAddress2 = '')  --IN00270982
      AND   (INSERTED.CarrierCity IS NULL OR INSERTED.CarrierCity = '')          --IN00270982
      AND   (INSERTED.CarrierKey <> '' AND INSERTED.CarrierKey IS NOT NULL)
   END
END -- Added for IDSV5 by June 21.Jun.02, (extract from IDSHK) *** Start
-- end

-- Added for IDSV5 by June 21.Jun.02, (extract from IDSTHAI) *** Start
IF @n_continue=1 OR @n_continue=2
BEGIN    
   SELECT @b_success = 0
   Execute nspGetRight @c_facility, -- facility
             @c_StorerKey,    -- Storerkey
             null,            -- Sku
             'UPD C4 ASNkey to ExtASNkey',      -- Configkey
             @b_success    output,
             @c_authority  output, 
             @n_err        output,
             @c_errmsg     output
   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
      SELECT @n_err = 60152
   END
   ELSE IF @c_authority = '1'
   BEGIN
    /*-- own asn key for CARREFOUR thailand -- */
    -- start
    IF EXISTS(SELECT storerkey FROM INSERTED WHERE STORERKEY BETWEEN 'C4LG000000' AND 'C4LGZZZZZZ') 
    BEGIN
      DECLARE @c_ASNKey NVARCHAR(6)
      EXECUTE   nspg_getkey
      "C4LGTHASN"
      , 6
      , @c_ASNKey OUTPUT
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT
      IF @b_success = 1
      BEGIN
        UPDATE RECEIPT SET trafficcop = NULL, externreceiptkey = 'C4LG' + @c_ASNKey
        FROM RECEIPT, INSERTED
        WHERE RECEIPT.receiptkey = INSERTED.receiptkey
      END
    END -- end
   END -- authority = 1
END -- Added for IDSV5 by June 21.Jun.02, (extract from IDSTHAI) *** End

IF @n_continue=1 OR @n_continue=2
BEGIN 
   SELECT @b_success = 0
   Execute nspGetRight @c_facility, -- facility
             @c_StorerKey,    -- Storerkey
             null,            -- Sku
             'UPD GTH ASNkey to ExtASNkey',     -- Configkey
             @b_success    output,
             @c_authority  output, 
             @n_err        output,
             @c_errmsg     output
   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
      SELECT @n_err = 60153
   END
   ELSE IF @c_authority = '1'
   BEGIN
      IF (SELECT storerkey FROM INSERTED) = 'GTH'
      BEGIN
        EXECUTE   nspg_getkey
        "GTHASN"
        , 4
        , @c_ASNKey OUTPUT
        , @b_success OUTPUT
        , @n_err OUTPUT
        , @c_errmsg OUTPUT
        IF (SELECT CONVERT(INT, @c_ASNKey)) = 0 
          UPDATE RECEIPT SET trafficcop = NULL, externreceiptkey = 'RR0001/02', pokey = 'RR0001/02'
          FROM RECEIPT, INSERTED
          WHERE RECEIPT.receiptkey = INSERTED.receiptkey
        ELSE
          UPDATE RECEIPT 
            SET trafficcop = NULL, 
                externreceiptkey = 'RR' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ASNKey)) + '/' + (right((year(getdate())),2)),
                pokey = 'RR' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ASNKey)) + '/' + (right((year(getdate())),2))
          FROM RECEIPT, INSERTED
          WHERE RECEIPT.receiptkey = INSERTED.receiptkey
          -- Added By SHONG 17th Mar 2003
          -- SOS# 6287 Do not issues RR No for Receipt Type = GRN
          AND   RECEIPT.RecType <> 'GRN' 
      END
   END
END

IF @n_continue=1 OR @n_continue=2
BEGIN
   UPDATE RECEIPT SET TrafficCop = NULL, AddDate = GETDATE(), AddWho=SUSER_SNAME(), EditDate = GETDATE(), EditWho=SUSER_SNAME() 
   FROM RECEIPT,inserted
   WHERE RECEIPT.ReceiptKey=inserted.ReceiptKey
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60154 --64001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Table RECEIPT. (nspReceiptHeaderAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
END

-- Added for IDSV5 by June 21.Jun.02, (extract from IDSMY) *** Start
IF @n_continue=1 OR @n_continue=2
BEGIN    
   SELECT @b_success = 0
   Execute nspGetRight @c_facility, -- facility
             @c_StorerKey,    -- Storerkey
             null,            -- Sku
             'FUJIASNREFNO',  -- Configkey
             @b_success    output,
             @c_authority  output, 
             @n_err        output,
             @c_errmsg     output
   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
      SELECT @n_err = 60155
   END
   ELSE IF @c_authority = '1'
   BEGIN
       -- Added By Shong
       -- Date: 23 Nov 2000
       -- Request By Siek Inn
       -- Purpose: Assign FUJI ASN Ref no before Finalize Receipt.
       DECLARE @c_GenerateStorerASNo NVARCHAR(1),
               @c_ReceiptKey NVARCHAR(10)
       DECLARE @c_insert_finalize NVARCHAR(1),
               @c_delete_finalize NVARCHAR(1),
               @c_key int
       SELECT @c_ReceiptKey = SPACE(10)
       WHILE 1=1
       BEGIN
          SELECT TOP 1 @c_ReceiptKey = RECEIPTKEY,
                 @c_StorerKey  = STORERKEY,
                 @c_RecType    = RecTYPE
          FROM   INSERTED
          WHERE  RECEIPTKEY > @c_ReceiptKey
          Order by RECEIPTKEY
          IF @@ROWCOUNT = 0
          BEGIN
             BREAK
          END

          IF @c_StorerKey = 'FUJI'
          BEGIN
             IF @c_rectype = 'NORMAL'
             BEGIN
              --  SELECT @c_key = ISNULL(MAX(CONVERT(INT, RIGHT(RECEIPT.carrierreference, 8))), 0) + 1
              -- remarked by Vicky 26 Aug 2002
              -- Modified by Vicky because the right function didnt work, so use the substring  
                SELECT @c_key = ISNULL(MAX(CONVERT(INT, SUBSTRING(RECEIPT.carrierreference, 3,8))), 0) + 1 
                FROM RECEIPT (NOLOCK)
                WHERE rectype = 'NORMAL'
                AND storerkey = 'FUJI'

                UPDATE RECEIPT
                SET RECEIPT.trafficcop = null,
                    RECEIPT.carrierreference = 'GR' + REPLICATE('0', 8 - LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(8), @c_key))))) + dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(8), @c_key)))
                FROM RECEIPT
                WHERE RECEIPT.receiptkey = @c_ReceiptKey
                AND RECEIPT.carrierreference IS NULL
             END
             ELSE
             BEGIN
                --SELECT @c_key = ISNULL(MAX(CONVERT(INT, RIGHT(RECEIPT.carrierreference, 8))), 0) + 1
                -- remarked by Vicky 26 Aug 2002
                -- Modified by Vicky because the right function didnt work, so use the substring
                SELECT @c_key = ISNULL(MAX(CONVERT(INT, SUBSTRING(RECEIPT.carrierreference, 3,8))), 0) + 1 
                FROM RECEIPT (NOLOCK)
                WHERE rectype <> 'NORMAL'
                AND storerkey = 'FUJI'

                UPDATE RECEIPT
                SET RECEIPT.trafficcop = null,
                    RECEIPT.carrierreference = 'TR' + REPLICATE('0', 8 - LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(8), @c_key))))) + dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(8), @c_key)))
                FROM RECEIPT
                WHERE RECEIPT.receiptkey = @c_ReceiptKey
                  AND RECEIPT.carrierreference IS NULL
             END
          END
       END -- While
   END
END
-- Added for IDSV5 by June 21.Jun.02, (extract from IDSMY) *** End


-- Added for IDSV5 by June 21.Jun.02, (extract from IDSPH) *** Start
IF @n_continue=1 OR @n_continue=2
BEGIN    
   SELECT @b_success = 0
   Execute nspGetRight @c_facility, -- facility
             @c_StorerKey,    -- Storerkey
             null,            -- Sku
             'RCPTRQD',       -- Configkey
             @b_success    output,
             @c_authority  output, 
             @n_err        output,
             @c_errmsg     output
   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
      SELECT @n_err = 60156
   END
   ELSE IF @c_authority = '1'
   BEGIN
      DECLARE  @c_warehousereference NVARCHAR(18),
               @c_warehouseorigin NVARCHAR(6),
               @c_reasoncode      NVARCHAR(10),
               @c_salesmancode    NVARCHAR(10),
               @c_customercode    NVARCHAR(18)

--     IF @c_value <> '1' -- acsie checking: shouldn't be setup in the storerconfig
--     BEGIN
         SELECT @c_warehousereference = warehousereference FROM INSERTED (NOLOCK)
         SELECT @c_rectype = rectype FROM INSERTED (NOLOCK) 
   
         -- warehousereference should be integer if 'RPO' and 'RRB'
         IF ISNUMERIC(@c_warehousereference) <> 1 AND @c_rectype IN ('RPO', 'RRB')
         BEGIN
            SELECT @n_continue = 3, @n_err = 60157 --50000
            SELECT @c_errmsg = 'VALIDATION ERROR: Invalid Warehouse Reference. Expecting Number Value.'
         END
   
         -- warehouse origin should not be null when 'RRB'
         IF @n_continue <> 3
         BEGIN
            SELECT @c_warehouseorigin = origincountry FROM INSERTED
            IF ISNULL(@c_warehouseorigin, " ") = " " AND @c_rectype = 'RRB'
            BEGIN
               SELECT @n_continue = 3, @n_err = 60158 --50000
               SELECT @c_errmsg = 'VALIDATION ERROR: Warehouse Origin Required.'
            END  
         END
   
         -- warehouse origin set to 'BIC-01' when 'RPO'
         IF @n_continue <> 3
         BEGIN
            IF @c_rectype = 'RPO'
            BEGIN 
               UPDATE RECEIPT
                  SET  RECEIPT.origincountry = FACILITY.UserDefine05 
                 FROM RECEIPT, INSERTED, FACILITY (NOLOCK) 
                WHERE RECEIPT.receiptkey = INSERTED.receiptkey 
                  AND FACILITY.FACILITY = INSERTED.FACILITY 
                  AND (INSERTED.origincountry = '' OR INSERTED.origincountry is NULL)
            END
         END
     
         -- reasoncode, salesmancode, warehousereference should not be null when 'RET'
         IF @n_continue <> 3  
         BEGIN
            SELECT @c_reasoncode = asnreason, @c_salesmancode = vehiclenumber,
               @c_customercode = carrierkey 
            FROM INSERTED
            IF ISNULL(@c_warehousereference, " ") = " " AND @c_rectype = 'RET'
            BEGIN
               SELECT @n_continue = 3, @n_err = 60159 --50000
               SELECT @c_errmsg = 'VALIDATION ERROR: Warehouse Reference Required.'
            END
          
            IF ISNULL(@c_customercode, " ") = " " AND @c_rectype = 'RET'
            BEGIN
               SELECT @n_continue = 3, @n_err = 60160 --50000
               SELECT @c_errmsg = 'VALIDATION ERROR: Customer Code (Carrier) Required.'
            END
            IF ISNULL(@c_reasoncode, " ") = " " AND @c_rectype = 'RET'
            BEGIN
               SELECT @n_continue = 3, @n_err = 60161 --50000
               SELECT @c_errmsg = 'VALIDATION ERROR: ASN Reason Code Required.'
            END
            --    ELSE IF (SELECT COUNT(*)
            --        FROM CODELKUP
            --        WHERE listname = 'ASNREASON'
            --               AND code = dbo.fnc_RTrim(dbo.fnc_LTrim(@c_reasoncode))) = 0 AND ISNULL(@c_reasoncode," ") <> " "
            --       BEGIN
            --          SELECT @n_continue = 3, @n_err = 50000
            --          SELECT @c_errmsg = 'VALIDATION ERROR: Invalid Reason Code.'
            --       END
            IF ISNULL(@c_salesmancode, " ") = " " AND @c_rectype = 'RET'
            BEGIN
               SELECT @n_continue = 3, @n_err = 60162 --50000
               SELECT @c_errmsg = 'VALIDATION ERROR: Salesman Code Required.'
            END
            ELSE IF (SELECT COUNT(*)
                     FROM CODELKUP
                     WHERE listname = 'SALESCODE'
                     AND code = dbo.fnc_RTrim(dbo.fnc_LTrim(@c_salesmancode))) = 0 AND ISNULL(@c_salesmancode," ") <> " "
            BEGIN
               SELECT @n_continue = 3, @n_err = 60163 --50000
               SELECT @c_errmsg = 'VALIDATION ERROR: Invalid Salesman Code.'
            END
   
            -- Date Modified 11/09/00
            -- BY: Gemma            
            -- If 'RET', there should be no duplicate ref#
   
            IF  EXISTS(SELECT RECEIPT.warehousereference 
            FROM  RECEIPT (nolock), inserted 
            WHERE RECEIPT.receiptkey <> INSERTED.receiptkey 
            AND  INSERTED.warehousereference  = RECEIPT.warehousereference) 
            AND @c_rectype = 'RET'
            BEGIN
               SELECT @n_continue = 3, @n_err = 60164 --50000
               SELECT @c_errmsg = 'RECORD EXISTS: Warehouse Reference (PCM#) Existing...'
            END    
         END
--    END -- @c_value <> '1'
   END -- Authority = '1'
 END 
-- Added for IDSV5 by June 21.Jun.02, (extract from IDSPH) *** End

-- tlting02 - JR WMS-2047 event track  
IF (@n_continue = 1 OR @n_continue = 2)  
BEGIN  
 SELECT @b_success = 0  
   
   EXECUTE nspGetRight NULL, -- facility  
          @c_storerkey,   -- Storerkey  
          NULL,     -- Sku  
          'GVTITF',        -- Configkey  
          @b_success output,  
          @c_authority output,  
          @n_err output,  
          @c_errmsg output  
            
 IF @b_success <> 1  
 BEGIN  
  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)  
      SELECT @n_err = 60265  
 END  
 ELSE IF @c_authority = '1'  
 BEGIN  
   SELECT @c_ReceiptKey = SPACE(10)  
   WHILE 1=1  
   BEGIN  
      SELECT TOP 1 @c_ReceiptKey = RECEIPTKEY  
      FROM   INSERTED  
      WHERE  RECEIPTKEY > @c_ReceiptKey  
      Order by RECEIPTKEY  
      IF @@ROWCOUNT = 0  
      BEGIN  
         BREAK  
      END  
      --SET @c_City = ''    
          SELECT @b_success=1    
  
          IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK) WHERE TableName = 'ASNSTS'    
                        AND DocumentNo = @c_ReceiptKey AND DOCStatus = '0' )    
          BEGIN                            
                          
            --SELECT @c_City = facility.City   
            --FROM   facility (NOLOCK)    
            --WHERE facility.facility = @c_facility  
   
            EXEC ispGenDocStatusLog 'ASNSTS', @c_storerkey, @c_ReceiptKey, '', '','0'  
            , @b_success OUTPUT    
            , @n_err OUTPUT    
            , @c_errmsg OUTPUT    
        
            IF @b_success <> 1    
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60266   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                 
               SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+    
                           ': Insert Failed On Table DocStatusTrack(ASNSTS). (ntrReceiptHeaderAdd)'+'('+    
                           'SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'                                  
            END   
  END -- not exists    
   END -- While  
 END    
END  
-- Added by MaryVong on 04-Jun-2004 (IDSHK-Nuance Watson: RA Export) - Start
-- Insert a record into TransmitLog2 table when populated from PO
IF (@n_continue = 1 OR @n_continue = 2)
BEGIN
   DECLARE @c_NWReceiptKey NVARCHAR(10),
           @c_DocType    NVARCHAR(1),
           @c_ASNStatus  NVARCHAR(1),
           @c_ExternReceiptKey NVARCHAR(50)   -- TLTING03
               
   SELECT @b_success = 0
   
   EXECUTE nspGetRight NULL,  -- facility
          @c_storerkey,       -- Storerkey
          NULL,               -- Sku
          'NWInterface',      -- Configkey
          @b_success output,
          @c_authority output,
          @n_err output,
          @c_errmsg output
          
   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
      SELECT @n_err = 60165
   END
   ELSE IF @c_authority = '1'
   BEGIN   
      SELECT @c_NWReceiptKey = INSERTED.ReceiptKey,
             @c_DocType = INSERTED.DocType,
             @c_ASNStatus = INSERTED.ASNStatus,
             @c_ExternReceiptKey = INSERTED.ExternReceiptKey
      FROM  INSERTED      
     
      IF @c_ASNStatus = '0' AND (@c_DocType = 'A' OR @c_DocType = 'X') AND
         dbo.fnc_RTrim(@c_ExternReceiptKey) <> '' AND dbo.fnc_RTrim(@c_ExternReceiptKey) IS NOT NULL
      BEGIN 
         SELECT @b_success = 1
-- SOS27626         EXEC ispGenTransmitLog2 'NWRA', @c_NWReceiptKey, '', @c_StorerKey, ''
         EXEC ispGenTransmitLog3 'NWRA', @c_NWReceiptKey, '', @c_StorerKey, ''                 -- SOS27626
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @n_err = 60166 --50001
            SELECT @c_errmsg = @c_receiptkey+ "," + @c_storerkey + "Unable to obtain transmitlogkey (ntrReceiptHeaderAdd)" 
         END
      END -- ASNStatus = '0', DocType = 'A' OR 'X', ExternReceiptKey <> '' OR null
   END -- Valid StorerConfig
END -- continue 
-- Added by MaryVong on 04-Jun-2004 (IDSHK-Nuance Watson: RA Export) - End

-- Added by June on 02-Apr-2009 (RCPTADD interface) - Start
IF (@n_continue = 1 or @n_continue = 2)
BEGIN
    DECLARE @c_RCPTADDITF NVARCHAR( 1)
    SELECT  @c_RCPTADDITF = 0, @b_success = 0

    SELECT @c_DocType = INSERTED.DocType
    FROM  INSERTED     

    EXECUTE nspGetRight NULL,  -- facility
    @c_storerkey,       -- Storerkey
    NULL,               -- Sku
    'RCPTADD',          -- Configkey
    @b_success output,
    @c_RCPTADDITF output,
    @n_err output,
    @c_errmsg output

    IF @b_success <> 1
    BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = 'ntrReceiptHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
    END
    ELSE IF @c_RCPTADDITF = '1'
    BEGIN
        SELECT @b_success = 1                                                             
        EXEC ispGenTransmitLog3 'RCPTADD', @cReceiptKey, @c_DocType, @c_storerkey, '' 
        , @b_success OUTPUT
        , @n_err OUTPUT
        , @c_errmsg OUTPUT

        IF @b_success <> 1
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60167
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
        END
    END -- Valid StorerConfig
END -- continue 
-- Added by June on 02-Apr-2009 (RCPTADD interface) - End

IF @n_continue=1 OR @n_continue=2
BEGIN    
   UPDATE RECEIPT 
      SET DOCTYPE = CASE INSERTED.RECTYPE 
                     WHEN 'NORMAL' THEN 'A'
                     WHEN 'RPO' THEN 'A'
                     WHEN 'RRB' THEN 'A'
                     WHEN 'TBLRRP' THEN 'A'
                     ELSE 'R' 
                    END, 
          TRAFFICCOP = NULL 
     FROM RECEIPT, INSERTED 
    WHERE RECEIPT.RECEIPTKEY = INSERTED.RECEIPTKEY 
      AND (dbo.fnc_RTrim(INSERTED.DOCTYPE) = '' OR INSERTED.DOCTYPE IS NULL) 
END

--(Wan02-v0) - START
SET @cur_ASN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT INSERTED.ReceiptKey
FROM  INSERTED WITH (NOLOCK)
CROSS APPLY dbo.fnc_SelectGetRight(INSERTED.Facility, INSERTED.Storerkey, '', 'AutoASNToTransportOrder') CFG
WHERE CFG.Authority = '1'

OPEN @cur_ASN

FETCH NEXT FROM @cur_ASN INTO @c_ReceiptKey

WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
BEGIN
   EXEC WM.lsp_ASNToTransportOrder
     @c_Receiptkey = @c_ReceiptKey
   , @b_Success    = @b_Success  OUTPUT
   , @n_Err        = @n_Err      OUTPUT
   , @c_ErrMsg     = @c_ErrMsg   OUTPUT
   , @c_UserName   = ''
   
   IF @b_Success = 0
   BEGIN 
      SET @n_Continue = 3
   END 
   FETCH NEXT FROM @cur_ASN INTO @c_ReceiptKey
END
CLOSE @cur_ASN
DEALLOCATE @cur_ASN
--(Wan02-v0) - END

-- Added by James on 04/10/2007 (SOS80707) Start
-- If storerconfig 'DefaultRoutingTool' setup (Svalue = '1'), default Receipt.RoutingTool = 'Y' (TMSHK)
IF @n_continue=1 OR @n_continue=2
BEGIN
   Declare @c_authority_DefaultRoutingTool NVARCHAR(1)
   Select @b_success = 0

   Execute nspGetRight @c_facility, 
                       @c_StorerKey,   -- Storer
                       NULL,           -- No Sku in this Case
                       'DefaultRoutingTool', -- ConfigKey
                       @b_success          output, 
                       @c_authority_DefaultRoutingTool    output, 
                       @n_err              output, 
                       @c_errmsg           output

   If @b_success <> 1
   Begin
      Select @n_continue = 3 
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60168   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Retrieve Failed On GetRight. (ntrOrderHeaderAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   End
   Else if @c_authority_DefaultRoutingTool = '1'
   Begin
      UPDATE RECEIPT  
      SET RoutingTool = 'Y', 
          trafficcop = NULL
      FROM RECEIPT, INSERTED 
      WHERE RECEIPT.RECEIPTKEY = INSERTED.RECEIPTKEY 
   End
END 
-- (80707) END 

-- (YokeBeen03) - Start
-- (YokeBeen01) - Start
IF @n_continue = 1 OR @n_continue=2  
BEGIN  
   DECLARE @c_Tablename NVARCHAR(30) 
   SELECT  @c_Tablename = ''

   -- (YokeBeen02) - Start
--remarked by James coz update routingtool will not update inserted.routingtool. have to join receipt   
--   IF EXISTS ( SELECT 1 FROM INSERTED 
--                 JOIN RECEIPT (NOLOCK) ON (INSERTED.ReceiptKey = RECEIPT.ReceiptKey)
--                 JOIN StorerConfig (NOLOCK) ON (StorerConfig.StorerKey = INSERTED.StorerKey AND 
--                                                ConfigKey IN ('TMSOutRtnHDR','TMSOutRtnDTL') AND sValue = '1')
--                 JOIN CODELKUP (NOLOCK) ON (INSERTED.RecType = CODELKUP.Code AND 
--                                            CODELKUP.Listname = 'TMSReturn')
--                WHERE INSERTED.RoutingTool = 'Y'  
--                  AND RECEIPT.DocType = 'R' )  -- (YokeBeen03)

   IF EXISTS ( SELECT 1 FROM INSERTED 
                 JOIN RECEIPT (NOLOCK) ON (INSERTED.ReceiptKey = RECEIPT.ReceiptKey)
                 JOIN StorerConfig (NOLOCK) ON (StorerConfig.StorerKey = INSERTED.StorerKey AND 
                                                ConfigKey IN ('TMSOutRtnHDR','TMSOutRtnDTL') AND sValue = '1')
                 JOIN CODELKUP (NOLOCK) ON (INSERTED.RecType = CODELKUP.Code AND 
                                            CODELKUP.Listname = 'TMSReturn')
                WHERE (INSERTED.RoutingTool = 'Y'  OR RECEIPT.RoutingTool = 'Y')
                  AND RECEIPT.DocType = 'R' )  -- (YokeBeen03)

   BEGIN
      SELECT DISTINCT @c_Tablename = ConfigKey
        FROM INSERTED 
        JOIN RECEIPT (NOLOCK) ON (INSERTED.ReceiptKey = RECEIPT.ReceiptKey)
        JOIN StorerConfig (NOLOCK) ON (StorerConfig.StorerKey = INSERTED.StorerKey AND 
                                       ConfigKey IN ('TMSOutRtnHDR','TMSOutRtnDTL') AND sValue = '1')
        JOIN CODELKUP (NOLOCK) ON (INSERTED.RecType = CODELKUP.Code AND 
                                   CODELKUP.Listname = 'TMSReturn')
       WHERE RECEIPT.DocType = 'R' 

-- (YokeBeen02) - Remarked
--       -- Update RECEIPT.RoutingTool = 'Y' 
--       UPDATE RECEIPT
--          SET RoutingTool = 'Y',
--              TrafficCop = NULL
--         FROM RECEIPT (NOLOCK)
--         JOIN INSERTED ON (INSERTED.ReceiptKey = RECEIPT.ReceiptKey)
--         JOIN StorerConfig WITH (NOLOCK) ON ( StorerConfig.StorerKey = RECEIPT.StorerKey AND 
--                                              ConfigKey IN ('TMSOutRtnHDR','TMSOutRtnDTL') AND sValue = '1' )
--         JOIN CODELKUP (NOLOCK) ON (RECEIPT.RecType = CODELKUP.Code AND 
--                                    CODELKUP.Listname = 'TMSReturn')
--        WHERE INSERTED.RoutingTool IS NULL 
--          AND INSERTED.DocType = 'R' 
-- 
--       IF @@ERROR = 0
--       BEGIN
--          SELECT @b_success = 0

         SET @cFac_TMSInterface = ''
         
         
         SELECT @cFac_TMSInterface = TMS_Interface 
         FROM INSERTED
         JOIN Receipt (NOLOCK) ON (INSERTED.ReceiptKey = Receipt.ReceiptKey)        
         JOIN Facility (NOLOCK) ON (Receipt.Facility = Facility.Facility )
         WHERE Receipt.ReceiptKey = @cReceiptKey
         
         SET @cRoute_TMSInterface = '' 
         SET @cRoute = ''
               
         SELECT @cRoute = StorerSODefault.Route 
         FROM INSERTED
         JOIN Receipt (NOLOCK) ON (INSERTED.ReceiptKey = Receipt.ReceiptKey)        
         JOIN StorerSODefault (NOLOCK) ON (Receipt.CarrierKey = StorerSODefault.StorerKey )
         WHERE Receipt.ReceiptKey = @cReceiptKey

         SELECT @cRoute_TMSInterface = TMS_Interface 
         FROM ROUTEMASTER (NOLOCK) 
         WHERE Route = CASE WHEN ISNULL(dbo.fnc_RTrim(@cRoute), '') = '' THEN 'PICKUP'    -- (tlting01) check with dbo.fnc_RTrim
         ELSE @cRoute END
         
         -- Insert records into TMSLog table 
         -- SOS80707 Add 'A' into Key2
         -- Assume if @cFac_TMSInterface & @cRoute_TMSInterface is null then treat it as 'Y'. Have to set 'N' to disable it
         -- (tlting01) check with dbo.fnc_RTrim         
         If ISNULL(dbo.fnc_RTrim(@cFac_TMSInterface), 'Y') = 'Y' AND ISNULL(dbo.fnc_RTrim(@cRoute_TMSInterface), 'Y') = 'Y'   
         BEGIN
            EXEC ispGenTMSLog @c_Tablename, @cReceiptKey, 'A', @c_StorerKey, ''
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
   
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60169   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into TMSLog Failed (ntrReceiptHeaderAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END
--       END -- IF @@ERROR = 0
--       ELSE
--       BEGIN
--          SELECT @n_continue = 3
--          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--          SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update into Receipt Failed (ntrReceiptHeaderAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
--       END 
-- (YokeBeen02) - Remarked
   END -- Valid StorerConfig check
   -- (YokeBeen02) - End
END 
-- (YokeBeen01) - End
-- (YokeBeen03) - End

/********************************************************/  
/* Interface Trigger Points Calling Process - (Start)   */  
/********************************************************/  
--MC01 - S
IF @n_continue = 1 OR @n_continue = 2   
BEGIN 

   DECLARE Cur_Itf_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT  DISTINCT INS.ReceiptKey 
   FROM    INSERTED INS 
   JOIN    ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey  
   WHERE   ITC.SourceTable = 'RECEIPT'  
   AND     ITC.sValue      = '1' 
   UNION                                                                                           
   SELECT DISTINCT IND.ReceiptKey                                                                    
   FROM   INSERTED IND                                                                             
   JOIN   ITFTriggerConfig ITC WITH (NOLOCK)                                                       
   ON     ITC.StorerKey   = 'ALL'                                                                  
   JOIN   StorerConfig STC WITH (NOLOCK)                                                           
   ON     STC.StorerKey   = IND.StorerKey AND STC.ConfigKey = ITC.ConfigKey AND STC.SValue = '1'   
   WHERE  ITC.SourceTable = 'RECEIPT'                                                               
   AND    ITC.sValue      = '1'                                                                    

   OPEN Cur_Itf_TriggerPoints
   FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_ReceiptKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      EXECUTE dbo.isp_ITF_ntrReceipt 
               @c_TriggerName    = 'ntrReceiptHeaderAdd'
             , @c_SourceTable    = 'RECEIPT'  
             , @c_ReceiptKey     = @c_ReceiptKey  
             , @c_ColumnsUpdated = ''        
             , @b_Success        = @b_Success   OUTPUT  
             , @n_err            = @n_err       OUTPUT  
             , @c_errmsg         = @c_errmsg    OUTPUT  

      FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_ReceiptKey
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE Cur_Itf_TriggerPoints
   DEALLOCATE Cur_Itf_TriggerPoints
END
--MC01 - E
/********************************************************/  
/* Interface Trigger Points Calling Process - (End)     */  
/********************************************************/  

      /* #INCLUDE <TRRHA2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   -- Rev 1.12 - To support RDT - start
   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   IF @n_IsRDT = 1
   BEGIN
      -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
      -- Instead we commit and raise an error back to parent, let the parent decide

      -- Commit until the level we begin with
      WHILE @@TRANCOUNT > @n_starttcnt
         COMMIT TRAN

      -- Raise error with severity = 10, instead of the default severity 16. 
      -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
      RAISERROR (@n_err, 10, 1) WITH SETERROR 

      -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
   END
   ELSE
   BEGIN
   -- Rev 1.12 - To support RDT - end

      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, "ntrReceiptHeaderAdd"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END
ELSE
BEGIN
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

END

GO