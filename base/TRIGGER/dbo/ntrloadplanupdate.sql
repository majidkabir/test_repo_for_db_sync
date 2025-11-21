SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ntrLoadPlanUpdate                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 13-Sep-2005  June      1.0   SOS40637 - bug fixed, no trxlog rec     */  
/*                              'ITSRCPT'.                              */  
/* 10-Sep-2007  Leong     1.0   SOS 85340 - Set Round (SKU.StdCube,6)   */  
/* 11-Mar-2009  YokeBeen  1.1   Added Trigger Point for CMS Project.    */  
/*                              - SOS#170508/170509 - (YokeBeen01)      */  
/* 06-May-2009  YokeBeen  1.2   Added Generic Trigger Point 'LOADSHPLOG'*/  
/*                              with Key1 = LoadKey. -- (YokeBeen02)    */  
/* 17-Feb-2010  ChewKP    1.3   Update LoadPlanLaneDetail to release    */  
/*                              Staging Lane when LP.Status = '9'       */  
/*                              (ChewKP01)                              */  
/* 08-Apr-2010  Vicky     1.4   Update LoadPlanLaneDetail to release    */  
/*                              Staging Lane should filter out those    */  
/*                              already has status = 9 (Vicky01)        */  
/* 04-May-2010  Leong     1.4   SOS# 171476 - Bug Fix on Status update  */  
/* 06-Aug-2010  TLTING    1.5   Cube & Weight Calculate status < 5      */  
/*                               (tlting01)                             */  
/* 22-May-2012  TLTING01  1.6   DM integrity - add update editdate B4   */
/*                              TrafficCop for status < '9'             */   
/* 10-Jul-2013  Shong     1.7   Include missing changes from UK         */
/* 28-Oct-2013  TLTING    1.8   Review Editdate column update           */
/* 03-Jun-2014  MCTang    1.9   Add New LOADFNZLOG (MC01)               */
/* 28-Nov-2014  TLTING    1.10  Performance Tuning                      */  
/* 03-Jun-2014  MCTang    1.11  Add New LOADFRCLOG (MC02)               */
/* 20-Sep-2016  MCTang    1.12  Enhance Generaic Trigger Interface &    */
/*                              OTMLOG Generaic Trigger Interface (MC03)*/
/* 16-Aug-2017  TLTING    1.13  Add TraceLog update ArchiveCop (TL01)   */ 
/* 11-Nov-2017  TLTING    1.14  Tune, verify LP status (TL01)           */ 
/* 15-Aug-2017  MCTang    1.13  Enhance Trigger Interface (MC04)        */
/* 04-Sep-2018  MCTang    1.14  Enhance Generaic Trigger Interface(MC05)*/
/* 20-Oct-2020  TLTING02  1.15  Performance tune                        */
/************************************************************************/

CREATE  TRIGGER [dbo].[ntrLoadPlanUpdate]
ON  [dbo].[LoadPlan]
FOR UPDATE
AS
IF @@ROWCOUNT = 0
BEGIN
   RETURN
END

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @b_Success     int       -- Populated by calls to stored procedures - was the proc successful?
      , @n_err         int       -- Error number returned by stored procedure or this trigger
      , @n_err2        int       -- For Additional Error Detection
      , @c_errmsg      NVARCHAR(250) -- Error message returned by stored procedure or this trigger
      , @n_continue    int
      , @n_starttcnt   int       -- Holds the current transaction count
      , @c_preprocess  NVARCHAR(250) -- preprocess
      , @c_pstprocess  NVARCHAR(250) -- post process
      , @n_cnt         int
      , @b_debug       int
      , @c_facility    NVARCHAR(5) -- Add For IDSV5 by June 26.Jun.02
      , @c_authority   NVARCHAR(1) -- Add For IDSV5 by June 26.Jun.02
      , @c_OWITF       NVARCHAR(1) -- Add For IDSV5 by June 26.Jun.02
      , @c_ITSITF      NVARCHAR(1) -- Add For IDSV5 By Ricky 30.Aug.02
      , @c_DPREPICK1   NVARCHAR(1) -- Add For IDSV5 By Ricky 30.Aug.02
      , @c_DPREPICK    NVARCHAR(1) -- Add For IDSV5 By Ricky 30.Aug.02
      , @c_NIKEREGITF  NVARCHAR(1) -- Add For NSC Project (SOS#15353) By YokeBeen on 14-Nov-2003
      , @c_LPPKCFMCMS  NVARCHAR(1) -- (YokeBeen01)
      , @c_LPSHPCFMCMS NVARCHAR(1) -- (YokeBeen01)
      , @c_LoadShpLog  NVARCHAR(1) -- (YokeBeen02)
      , @c_LOADFNZLOG  NVARCHAR(1) -- (MC01)
      , @c_LOADFRCLOG  NVARCHAR(1) -- (MC02)

-- Start - Modified by YokeBeen on 30-Apr-2002 (FBR089)
DECLARE @c_XStorerkey   NVARCHAR(15)
      , @c_trmlogkey    NVARCHAR(10)
      , @c_XLoadKey     NVARCHAR(10)
      , @c_PICKTRF      NVARCHAR(1)
-- End

DECLARE @c_FinalizeFlag    NVARCHAR(1)
      , @c_Userdefine08    NVARCHAR(10)
      , @c_PreFinFlag      NVARCHAR(1)
      , @c_EditWho         NVARCHAR(18)
      , @c_LoadKey         NVARCHAR(10)   
      , @c_Storerkey       NVARCHAR(15)   --(MC03)
      , @c_StatusUpdated   CHAR(1)        --(MC04) 
      , @c_Proceed         CHAR(1)        --(MC04)
      , @c_COLUMN_NAME     VARCHAR(50)    --(MC04) 
      , @c_ColumnsUpdated  VARCHAR(1000)  --(MC04)

DECLARE @c_TraceKey           NVARCHAR(10)         --(TL01)  
      , @c_ArchiveCop         NVARCHAR(10) = ''    --(TL01)  
      , @c_InsertedStatus     NVARCHAR(10) = ''    --(TL01)  

DECLARE @c_LP_Min_Status      NVARCHAR(10) = '0'     --(TL01)  
      , @c_LP_Max_Status      NVARCHAR(10) = '0'     --(TL01)  

SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT, @b_debug = 0
SET @c_StatusUpdated = 'N'                --(MC04)
SET @c_Proceed       = 'N'                --(MC04)     

IF UPDATE(ArchiveCop)
BEGIN
   SELECT @n_continue = 4
   --SELECT @c_TraceKey = LoadKey
   --     , @c_ArchiveCop = ArchiveCop
   --     , @c_InsertedStatus = [STATUS]
   --FROM INSERTED
   --IF @c_InsertedStatus <> '9' AND @c_ArchiveCop = '9'
   --   BEGIN
   --      EXEC isp_Sku_Log '', @c_TraceKey, 'UPD-Load', '', @c_ArchiveCop --(TL01) 
   --      EXEC isp_Sku_Log '', @c_TraceKey, 'UPD-Load', 'stutus', @c_InsertedStatus --(TL01)  
   --   END
END

DECLARE @b_ColumnsUpdated VARBINARY(1000)       --MC03
SET @b_ColumnsUpdated = COLUMNS_UPDATED()       --MC03

-- tlting01
IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
            WHERE INSERTED.LoadKey = DELETED.LoadKey
            AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) ) 
   AND (@n_continue=1 or @n_continue=2)
   AND NOT UPDATE(EditDate)
BEGIN
   UPDATE LoadPlan  
   SET EditDate = GETDATE(), EditWho=SUSER_SNAME(),
         TrafficCop = NULL       
   FROM LoadPlan,INSERTED       
   WHERE LoadPlan.LoadKey=INSERTED.LoadKey      
   AND LoadPlan.[status] < '9'
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT             
   IF @n_err <> 0      
   BEGIN      
      SELECT @n_continue = 3       
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72815      
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On LoadPlan. (ntrLoadPlanUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
   END      
END 

IF UPDATE(TrafficCop)
BEGIN
   SELECT @n_continue = 4
END

/* #INCLUDE <TRMBOHU1.SQL> */
IF @n_continue=1 or @n_continue=2
BEGIN
   IF EXISTS (SELECT * FROM DELETED WHERE Status = '9')
   BEGIN
      SELECT @n_continue=3
      SELECT @n_err=72810
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                       + ': UPDATE rejected. LoadPlan.Status = ''SHIPPED''. (ntrLoadPlanUpdate)'
   END
END

IF @n_continue=1 or @n_continue=2
BEGIN
   DECLARE @c_FinalizeLP NVARCHAR(1)
   SELECT @b_success = 0

   Execute nspGetRight null,  -- facility
            null,      -- Storerkey
            null,      -- Sku
            'FinalizeLP', -- Configkey
            @b_success    output,
            @c_FinalizeLP output,
            @n_err        output,
            @c_errmsg     output

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg)
   END
END

-- Start - Add by June 31.Jan.02 FBR039
IF (@n_continue=1 or @n_continue=2) AND UPDATE(FinalizeFlag)
BEGIN
   DECLARE @c_XOrderKey  NVARCHAR(30)
   SELECT @c_XOrderKey = SPACE(30)

   DECLARE C_Loadplan_Add CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LOADPLANDETAIL.OrderKey,
          ORDERS.Storerkey,
          LOADPLANDETAIL.LoadKey,
          INSERTED.FinalizeFlag,
          DELETED.FinalizeFlag,
          ORDERS.Userdefine08
   FROM   INSERTED
   JOIN   DELETED ON (INSERTED.LoadKey = DELETED.LoadKey)
   JOIN   LOADPLANDETAIL WITH (NOLOCK) ON (INSERTED.Loadkey = LOADPLANDETAIL.Loadkey)
   JOIN   ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = Orders.Orderkey
                               and LOADPLANDETAIL.Loadkey = ORDERS.Loadkey)
   ORDER BY LOADPLANDETAIL.OrderKey

   OPEN C_Loadplan_Add

   FETCH NEXT FROM C_Loadplan_Add INTO
      @c_XOrderKey,   @c_XStorerkey,  @c_XLoadKey, @c_FinalizeFlag, @c_PreFinFlag, @c_UserDefine08

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @b_success = 0
      SELECT @c_DPREPICK = 0  -- Modified by June 20.Feb.03 FBR9706
      SELECT @c_DPREPICK1 = 0 -- Modified by June 20.Feb.03 FBR9706


      IF @c_FinalizeFlag = 'Y' AND @c_PreFinFlag <> 'Y'
      BEGIN
         Execute nspGetRight null, -- facility
         @c_XStorerkey,   -- Storerkey
         null,            -- Sku
         'OWITF',         -- Configkey
         @b_success    output,
         @c_OWITF      output,
         @n_err        output,
         @c_errmsg     output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg)
         END

         IF @b_success = 1 AND @c_OWITF = '1'
         BEGIN
            -- Add by June 8.Aug.02
            -- Status 542 for Discrete Prepick is send during Print Discrete Pickslip
            -- Dun send again in LP finalize

            SELECT @b_success = 0
            Execute nspGetRight null, -- facility
            @c_XStorerkey,   -- Storerkey
            null,   -- Sku
            'DPREPICK',-- Configkey
            @b_success    output,
            @c_DPREPICK   output,
            @n_err        output,
            @c_errmsg     output
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg)
            END

            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 0
               Execute nspGetRight null, -- facility
               @c_XStorerkey,   -- Storerkey
               null,   -- Sku
               'DPREPICK+1',-- Configkey
               @b_success    output,
               @c_DPREPICK1  output,
               @n_err        output,
               @c_errmsg     output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg)
               END
            END

            -- Modified by June 20.Feb.03 FBR9706 -- Cater for storer with no 'DPREPICK/DPREPICK+1' config setup.
            -- IF @b_success = 1 AND @c_DPREPICK <> '1' AND @c_DPREPICK1 <> '1'
            IF @c_DPREPICK <> '1' AND @c_DPREPICK1 <> '1'
            BEGIN
               -- Start - Add by June 20.Feb.03 FBR9706
               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  IF @c_Userdefine08 = 'Y'
                  BEGIN
                     SELECT @b_success = 0
                     Execute nspGetRight null, -- facility
                     @c_XStorerkey,   -- Storerkey
                     null,   -- Sku
                     'PICK-TRF',-- Configkey
                     @b_success    output,
                     @c_PICKTRF    output,
                     @n_err        output,
                     @c_errmsg     output

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg)
                     END
                  END
                  ELSE
                     SELECT @c_PICKTRF = '0'
               END
               -- End - FBR9706

               IF @c_PICKTRF = '0'
               BEGIN
                  EXEC ispGenTransmitLog 'OWLPLAN', @c_XOrderKey, '', '', ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72801
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                      + ': Unable to obtain transmitlogkey (ntrLoadPlanUpdate)'
                                      + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '  
                  END
               END -- DPREPICK & DPREPICK+1 not ON
               ELSE
               BEGIN
                  -- DPREPICK / DPREPICK+1 ON, Insert OWLPLAN for Existing Pending Orders
                  -- Need to remove later, say in 2002 NOV
                  IF EXISTS (SELECT 1 FROM TransmitLog WITH (NOLOCK)
                              WHERE TableName = 'OWORDALLOC' AND Key1 = @c_XOrderKey )
                  BEGIN
                     EXEC ispGenTransmitLog 'OWLPLAN', @c_XOrderKey, '', '', ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72802
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                         + ': Unable to obtain transmitlogkey (ntrLoadPlanUpdate)'
                                         + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
                     END
                  END -- not exists in transmitlog, OWORDALLOC
               END -- DPREPICK & DPREPICK+1 ON
            END -- @c_DPREPICK <> '1' AND @c_DPREPICK1 <> '1'
         END -- OWITF = '1'

         SELECT @c_ITSITF = '0'
         Execute nspGetRight null, -- facility
                  @c_XStorerkey,   -- Storerkey
                  null,            -- Sku
                  'ITSITF',        -- Configkey
                  @b_success    output,
                  @c_ITSITF      output,
                  @n_err        output,
                  @c_errmsg     output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg)
         END

         IF @b_success = 1 AND @c_ITSITF = '1'
         BEGIN
         -- Added by YokeBeen on 10-March-2002 -- FBR089
            EXEC ispGenTransmitLog 'ITSORD', @c_XLoadKey, '', @c_XOrderKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72803
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                + ': Unable to Generate transmitlog Record, TableName = ITSORD (ntrLoadPlanUpdate)'
                                + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
            END
         END

         -- Added by Shong om 9-Aug-2003 SOS#12796 NIKEHK Interface
         IF EXISTS (SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerConfig.StorerKey = @c_XStorerkey
                       AND StorerConfig.ConfigKey = 'NIKEHK_LOADPLAN' AND StorerConfig.sValue = '1')
         BEGIN -- End - SOS#12796
            EXEC ispGenTransmitLog 'NIKEHKLP', @c_XLoadKey, '', @c_XOrderKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72804
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                + ': Unable to Generate NSCLog Record, TableName = NIKEHKLP (ntrLoadPlanUpdate)'
                                + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
            END
         END -- End - SOS#12796

         -- Added by YokeBeen on 14-Nov-2003 - Nike Regional Interface (NSC Project)
         -- (SOS#15353) - 'S' - Scheduled. This is the only absolute requirement.
         SELECT @c_NIKEREGITF = 0
         SELECT @b_success = 0

         EXECUTE nspGetRight
                  NULL,            -- Facility
                  @c_XStorerkey,   -- Storerkey
                  NULL,            -- Sku
                  'NIKEREGITF',    -- Configkey
                  @b_success    output,
                  @c_NIKEREGITF output,
                  @n_err        output,
                  @c_errmsg     output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg)
         END

         IF @b_success = 1 AND @c_NIKEREGITF = '1'
         BEGIN
            -- Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
            -- Changed to trigger records into NSCLog table with 'NSCKEY'.
            EXEC ispGenNSCLog 'NIKEREGDSS', @c_XLoadKey, '', @c_XOrderKey, ''
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72805
               SELECT @c_errmsg = 'NSQL' +CONVERT(char(5),ISNULL(@n_err,0))
                                + ': Unable to Generate NSCLog Record, TableName = NIKEREGDSS (ntrLoadPlanUpdate)'
                                + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
            END
            -- End Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project (SOS#20000)
         END -- IF @b_success = 1 AND @c_NIKEREGITF = '1'
         -- End - (SOS#15353) - NSC Project
      END -- If update Finalize Flag
      FETCH NEXT FROM C_Loadplan_Add INTO
      @c_XOrderKey,   @c_XStorerkey,  @c_XLoadKey, @c_FinalizeFlag, @c_PreFinFlag, @c_UserDefine08
   END -- while
   CLOSE C_Loadplan_Add
   DEALLOCATE C_Loadplan_Add
END -- continue = 1

-- Start - Added by YokeBeen on 30-Apr-2002 (FBR089)
IF @n_continue=1 or @n_continue=2
BEGIN
   IF UPDATE(Finalizeflag) AND
      EXISTS( SELECT 1 FROM INSERTED
              JOIN   LOADPLANRETDETAIL WITH (NOLOCK) ON (INSERTED.Loadkey = LOADPLANRETDETAIL.Loadkey)
              WHERE  INSERTED.FinalizeFlag = 'Y')
   BEGIN
      DECLARE @c_XReceiptKey  NVARCHAR(30)
      SELECT @c_XReceiptKey = SPACE(30)

      DECLARE C_Loadplan_Add CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LOADPLANRETDETAIL.ReceiptKey,
             RECEIPT.Storerkey,
             LOADPLANRETDETAIL.LoadKey
      FROM   INSERTED
      JOIN   LOADPLANRETDETAIL WITH (NOLOCK) ON (INSERTED.Loadkey = LOADPLANRETDETAIL.Loadkey)
      JOIN   RECEIPT WITH (NOLOCK) ON (LOADPLANRETDETAIL.Receiptkey = RECEIPT.Receiptkey
                                   AND LOADPLANRETDETAIL.Loadkey = RECEIPT.Loadkey)
      JOIN   StorerConfig WITH (NOLOCK) ON (RECEIPT.StorerKey = StorerConfig.StorerKey
      AND    StorerConfig.ConfigKey = 'OWITF' AND StorerConfig.sValue = '1')
      WHERE  INSERTED.FinalizeFlag = 'Y'
      ORDER BY LOADPLANRETDETAIL.ReceiptKey

      OPEN C_Loadplan_Add

      FETCH NEXT FROM C_Loadplan_Add INTO @c_XReceiptKey, @c_XStorerkey, @c_XLoadKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Start : SOS40637
         -- IF @@ROWCOUNT = 0
         -- BREAK
         -- End : SOS40637

         IF NOT EXISTS (SELECT 1 FROM TransmitLog WITH (NOLOCK) WHERE TableName = 'ITSRCPT'
                        AND    Key3 = @c_XReceiptKey )
         BEGIN
            SELECT @b_success = 1

            EXEC ispGenTransmitLog 'ITSRCPT', @c_XLoadKey, '', @c_XReceiptKey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                + ': Unable to Generate transmitlog Record, TableName = ITSRCPT (ntrLoadPlanUpdate)'
                                + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
            END
         END -- not exists in transmitlog, ITSRCPT
         FETCH NEXT FROM C_Loadplan_Add INTO @c_XReceiptKey, @c_XStorerkey, @c_XLoadKey
      END -- while
      CLOSE C_Loadplan_Add
      DEALLOCATE C_Loadplan_Add

      --MC02 - S
      SELECT TOP 1 @c_XStorerkey = RECEIPT.Storerkey
                 , @c_XLoadKey = LOADPLANRETDETAIL.LoadKey
      FROM   INSERTED
      JOIN   LOADPLANRETDETAIL WITH (NOLOCK) 
      ON     (INSERTED.Loadkey = LOADPLANRETDETAIL.Loadkey)
      JOIN   RECEIPT WITH (NOLOCK) 
      ON     (LOADPLANRETDETAIL.Receiptkey = RECEIPT.Receiptkey
              AND LOADPLANRETDETAIL.Loadkey = RECEIPT.Loadkey)
      WHERE  INSERTED.FinalizeFlag = 'Y'

      SELECT @c_LOADFRCLOG = 0
      SELECT @b_success = 0

      EXECUTE nspGetRight
               NULL,                  -- Facility
               @c_XStorerkey,         -- Storerkey
               NULL,                  -- Sku
               'LOADFRCLOG',          -- Configkey
               @b_success    output,
               @c_LOADFRCLOG output,
               @n_err        output,
               @c_errmsg     output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg) 
      END

      IF @b_success = 1 AND @c_LOADFRCLOG = '1'
      BEGIN
         EXEC ispGenTransmitLog3 'LOADFRCLOG', @c_XLoadKey, '', @c_XStorerkey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72808
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                             + ': Unable to Generate CMSLog Record, TableName = LOADFNZLOG (ntrLoadPlanUpdate)'
                             + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
         END
      END -- IF @b_success = 1 AND @c_LPPKCFMCMS = '1'
      --MC02 - E
   END -- Update FinalizeFlag
END -- End - FBR089

-- Added for IDSV5 by June 26.Jun.02, (extract from IDSHK) *** Start
IF @n_continue=1 or @n_continue=2
BEGIN
   DECLARE @c_CurrentLoad NVARCHAR(10)
         , @c_Status      NVARCHAR(1)
         , @c_LPStatus    NVARCHAR(1)

   DECLARE
      @n_Alloc_CaseCnt     int,
      @n_Alloc_PalletCnt   int,
      @n_Alloc_Weight      float,
      @n_Alloc_Cube        float,
      @n_Alloc_CustCnt     int,
      @n_Alloc_OrderCnt    int

   SELECT @c_CurrentLoad = SPACE(10)

   DECLARE C_Loadplan_Add CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
    SELECT INSERTED.LoadKey, INSERTED.Status, INSERTED.FinalizeFlag, INSERTED.EditWho
      FROM INSERTED
     ORDER BY INSERTED.LoadKey

   OPEN C_Loadplan_Add

   FETCH NEXT FROM C_Loadplan_Add INTO @c_CurrentLoad, @c_LPStatus, @c_FinalizeFlag, @c_EditWho

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- (YokeBeen02) - Start
      DECLARE @c_CurrentStorerKey NVARCHAR(15)
            , @c_CurrentFacility NVARCHAR(5)
      SET @c_CurrentStorerKey = ''
      SET @c_CurrentFacility = ''

      SELECT @c_Status = ''
      -- SOS# 171476 (Start)
      -- SELECT @c_Status = CASE
      --                       WHEN MAX(LOADPLANDETAIL.Status) = '0'
      --                          THEN '0'
      --                       WHEN MIN(LOADPLANDETAIL.Status) = '0' and MAX(LOADPLANDETAIL.Status) >= '1'
      --                          THEN '1'
      --                       ELSE MIN(LOADPLANDETAIL.Status)
      --                    END
      --   , @c_CurrentStorerKey = ORDERS.Storerkey
      --   , @c_CurrentFacility = LOADPLAN.Facility
      -- FROM LOADPLANDETAIL WITH (NOLOCK)
      -- JOIN LOADPLAN WITH (NOLOCK) ON (LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey)
      -- JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = LOADPLANDETAIL.OrderKey)
      -- WHERE LOADPLANDETAIL.Loadkey = @c_CurrentLoad
      -- GROUP BY ORDERS.Storerkey, LOADPLAN.Facility

      --(TL01) - S
      /*
      SELECT @c_Status = CASE
                           WHEN MAX(Status) = '0'
                              THEN '0'
                           WHEN MIN(Status) = '0' and MAX(Status) >= '1'
                              THEN '1'
                           ELSE MIN(Status)
                         END
      FROM  LOADPLANDETAIL WITH (NOLOCK)
      WHERE Loadkey = @c_CurrentLoad
      */

   	SELECT @c_LP_Min_Status = '0', 
   	       @c_LP_Max_Status = '0' 
   	             	
   	SELECT @c_LP_Min_Status = MIN(STATUS), 
   	       @c_LP_Max_Status = MAX(STATUS) 
   	FROM   LoadPlanDetail AS lpd WITH (NOLOCK)
   	WHERE  lpd.LoadKey = @c_CurrentLoad 
   	AND    lpd.[Status] NOT IN ('CANC')      	      

      SET @c_Status = CASE
                       WHEN @c_LP_Max_Status = '0' THEN '0'
                       WHEN @c_LP_Min_Status = '0' and @c_LP_Max_Status IN ('1','2')
                          THEN '1'
                       WHEN @c_LP_Min_Status IN ('0','1','2') AND @c_LP_Max_Status IN ('3','5')
                          THEN '3'
                       ELSE @c_LP_Min_Status
                    END  
      --(TL01) - E

      -- TLTING    1.10   Performance Tuning      
      SELECT TOP 1 @c_CurrentStorerKey = (ORDERS.Storerkey)  
                 , @c_CurrentFacility = (LOADPLAN.Facility)  
      FROM LOADPLAN WITH (NOLOCK)  
      JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey)   --TLTING02
      JOIN ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)  
      WHERE LOADPLAN.Loadkey = @c_CurrentLoad   


      DECLARE @cDoNotCalcLPAllocInfo VARCHAR(10)  
  
      SET @cDoNotCalcLPAllocInfo = ''  
  
      SELECT @cDoNotCalcLPAllocInfo = ISNULL(sValue, '0')   
      FROM  STORERCONFIG WITH (NOLOCK)   
      WHERE StorerKey = @c_CurrentStorerKey   
      AND   ConfigKey = 'DoNotCalcLPAllocInfo'   
      AND   sVAlue = '1'  

      -- SOS# 171476 (End)
            
      IF ISNULL(RTRIM(@c_LPStatus),'') < '9'     
      BEGIN
         -- if status is null means no loadplan detail... stop process  
         IF ISNULL(RTrim(@c_Status),'') <> ''  
         BEGIN  
            SET @n_Alloc_CaseCnt     =0  
            SET @n_Alloc_PalletCnt   =0  
            SET @n_Alloc_Weight      =0  
            SET @n_Alloc_Cube        =0  
            SET @n_Alloc_CustCnt     =0  
            SET @n_Alloc_OrderCnt    =0  
            
            -- only get the allocated info when order detail status > 0
            IF @c_Status > '0' AND @c_LPStatus < '5' AND @cDoNotCalcLPAllocInfo <> '1'  
            BEGIN
               -- tlting01
               SELECT @n_Alloc_PalletCnt =     
                         CONVERT(Integer, SUM(CASE WHEN PACK.Pallet = 0 THEN 0    
                         ELSE ((OrderDetail.QtyAllocated + OrderDetail.QtyPicked) / PACK.Pallet) END)),    
                      @n_Alloc_CaseCnt =     
                         CONVERT(Integer, SUM(CASE WHEN PACK.CaseCnt = 0 THEN 0    
                         ELSE ((OrderDetail.QtyAllocated + OrderDetail.QtyPicked) / PACK.CaseCnt) END)),    
                      @n_Alloc_Cube = SUM((ORDERDETAIL.QtyAllocated + OrderDetail.QtyPicked) * ROUND(SKU.StdCube,6)), -- SOS 85340    
                      @n_Alloc_Weight = SUM((OrderDetail.QtyAllocated + OrderDetail.QtyPicked) * SKU.StdGrossWgt)
             FROM LoadPlanDetail WITH (NOLOCK)    
                 JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = LoadPlanDetail.OrderKey)     
                 JOIN PACK WITH (NOLOCK) ON (ORDERDETAIL.Packkey = PACK.Packkey)    
                 JOIN SKU WITH (NOLOCK, INDEX (PKSKU) ) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.SKU = SKU.SKU)     
                WHERE LoadPlandetail.LoadKey = @c_CurrentLoad     
                  AND (ORDERDETAIL.QtyAllocated + OrderDetail.QtyPicked + ORDERDETAIL.ShippedQty) > 0     
  
               SELECT @n_Alloc_OrderCnt = COUNT(DISTINCT LoadPlanDetail.OrderKey),    
                      @n_Alloc_CustCnt = COUNT(DISTINCT  LoadPlanDetail.ConsigneeKey)    
                 FROM LoadPlanDetail WITH (NOLOCK)    
                WHERE LoadPlandetail.LoadKey = @c_CurrentLoad     
                
               IF @n_Alloc_CaseCnt   IS NULL SELECT @n_Alloc_CaseCnt = 0
               IF @n_Alloc_Weight    IS NULL SELECT @n_Alloc_Weight = 0
               IF @n_Alloc_Cube      IS NULL SELECT @n_Alloc_Cube = 0
               IF @n_Alloc_OrderCnt  IS NULL SELECT @n_Alloc_OrderCnt = 0
               IF @n_Alloc_PalletCnt IS NULL SELECT @n_Alloc_PalletCnt = 0
               IF @n_Alloc_CustCnt   IS NULL SELECT @n_Alloc_CustCnt = 0
               
            END --IF @c_Status > '0' AND @c_LPStatus < '5' AND @cDoNotCalcLPAllocInfo <> '1'  

            IF @c_FinalizeLP =  '1'
            BEGIN
               IF @c_FinalizeFlag <> 'Y' OR @c_LPStatus > '5'
                  SELECT @c_Status = @c_LPStatus
            END
            ELSE
            BEGIN
               IF @c_LPStatus > '5'
                  SELECT @c_Status = @c_LPStatus
            END

            IF @c_LPStatus < '5'  -- Update only allocate order
            BEGIN
               
               SET @c_StatusUpdated = 'Y' -- (MC04)
               
               UPDATE LoadPlan  
                  SET AllocatedCustCnt   = @n_Alloc_CustCnt,
                      AllocatedOrderCnt  = @n_Alloc_OrderCnt,
                      AllocatedWeight    = @n_Alloc_Weight,
                      AllocatedCube      = @n_Alloc_Cube,
                      AllocatedPalletCnt = @n_Alloc_PalletCnt,
                      AllocatedCaseCnt   = @n_Alloc_CaseCnt,
                      Status = @c_Status,
                      EditDate = GETDATE(),  --tlting
                      EditWho = SUSER_SNAME(),
                      trafficcop = NULL
               WHERE LoadKey = @c_CurrentLoad
            END
            ELSE                 -- else only update status
            BEGIN

               SET @c_StatusUpdated = 'Y' -- (MC04)

               UPDATE LoadPlan  
                  SET Status = @c_Status,
                      EditWho = SUSER_SNAME(),
                      trafficcop = NULL,
                      EditDate = GETDATE()  --tlting
               WHERE LoadKey = @c_CurrentLoad               
            END

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
                  BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 72807
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                + ': Unable to Update LoadPlan table (ispUpdateAllocatedLoad)'
                                + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
            END
         END -- STATUS Not = BLANK 
      END -- IF ISNULL(RTRIM(@c_LPStatus),'') < '9'

      -- CMS Project Start - (YokeBeen01)
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF @c_Status = '5'
         BEGIN
            SELECT @c_LPPKCFMCMS = 0
            SELECT @b_success = 0

            EXECUTE nspGetRight
                     NULL,                  -- Facility
                     @c_CurrentStorerKey,   -- Storerkey
                     NULL,                  -- Sku
                     'LPPKCFMCMS',          -- Configkey
                     @b_success    output,
                     @c_LPPKCFMCMS output,
                     @n_err        output,
                     @c_errmsg     output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg) 
            END

            IF @b_success = 1 AND @c_LPPKCFMCMS = '1'
            BEGIN
               EXEC ispGenCMSLog 'LPPKCFMCMS', @c_CurrentLoad, 'L', @c_CurrentStorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72808
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                   + ': Unable to Generate CMSLog Record, TableName = LPPKCFMCMS (ntrLoadPlanUpdate)'
                                   + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
               END
            END -- IF @b_success = 1 AND @c_LPPKCFMCMS = '1'
         END -- IF @c_Status = '5'
         ELSE IF @c_Status = '9'
         BEGIN
            SELECT @c_LPSHPCFMCMS = 0
            SELECT @b_success = 0

            EXECUTE nspGetRight
                     NULL,                  -- Facility
                     @c_CurrentStorerKey,   -- Storerkey
                     NULL,                  -- Sku
                     'LPSHPCFMCMS',         -- Configkey
                     @b_success     output,
                     @c_LPSHPCFMCMS output,
                     @n_err         output,
                     @c_errmsg      output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg) 
            END

            IF @b_success = 1 AND @c_LPSHPCFMCMS = '1'
            BEGIN
               EXEC ispGenCMSLog 'LPSHPCFMCMS', @c_CurrentLoad, 'L', @c_CurrentStorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72809
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                   + ': Unable to Generate CMSLog Record, TableName = LPSHPCFMCMS (ntrLoadPlanUpdate)'
                                   + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '  
               END
            END -- IF @b_success = 1 AND @c_LPSHPCFMCMS = '1'
         -- CMS Project End - (YokeBeen01)


            SELECT @c_LoadShpLog = 0
            SELECT @b_success = 0

            EXECUTE nspGetRight
                     NULL,                 -- Facility
                     @c_CurrentStorerKey,  -- Storerkey
                     NULL,                 -- Sku
                     'LOADSHPLOG',         -- Configkey
                     @b_success     output,
                     @c_LoadShpLog  output,
                     @n_err         output,
                     @c_errmsg      output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg) 
            END

            IF @b_success = 1 AND @c_LoadShpLog = '1'
            BEGIN
               EXEC ispGenTransmitLog3 'LOADSHPLOG', @c_CurrentLoad, @c_CurrentFacility, @c_CurrentStorerKey, ''
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72810
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                   + ': Unable to Generate TransmitLog3 Record, TableName = LOADSHPLOG (ntrLoadPlanUpdate)'
                                   + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) ' 
               END
            END -- IF @b_success = 1 AND @c_LoadShpLog = '1'

            -- Update Staging Lane on LoadPlanLaneDetail -- START (ChewKP01)
            IF EXISTS (SELECT 1 FROM LOADPLANLANEDETAIL LPL WITH (NOLOCK)
                       WHERE LPL.Loadkey = @c_CurrentLoad
                       AND LPL.Status = '0')
            BEGIN
               Update LoadPlanLaneDetail  
                  SET Status = '9',
                      EditDate = GETDATE(),        --tlting
                      EditWho = SUSER_SNAME()
               Where Loadkey = @c_CurrentLoad
               AND   Status = '0' -- (Vicky01)
            END
            -- Update Staging Lane on LoadPlanLaneDetail -- END(ChewKP01)


         END -- ELSE IF @c_Status = '9'
      END -- IF @n_continue = 1 OR @n_continue = 2
      -- (YokeBeen02) - End
   
      --MC01 - S
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF UPDATE(Finalizeflag) AND @c_FinalizeFlag = 'Y'
         BEGIN
            SELECT @c_LOADFNZLOG = 0
            SELECT @b_success = 0

            EXECUTE nspGetRight
                     NULL,                  -- Facility
                     @c_CurrentStorerKey,   -- Storerkey
                     NULL,                  -- Sku
                     'LOADFNZLOG',          -- Configkey
                     @b_success    output,
                     @c_LOADFNZLOG output,
                     @n_err        output,
                     @c_errmsg     output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlanUpdate' + RTrim(@c_errmsg) 
            END

            IF @b_success = 1 AND @c_LOADFNZLOG = '1'
            BEGIN
               EXEC ispGenTransmitLog3 'LOADFNZLOG', @c_CurrentLoad, @c_CurrentFacility, @c_CurrentStorerKey, ''
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72808
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                   + ': Unable to Generate CMSLog Record, TableName = LOADFNZLOG (ntrLoadPlanUpdate)'
                                   + ' ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
               END
            END -- IF @b_success = 1 AND @c_LPPKCFMCMS = '1'
         END
      END
      --MC01 - E

      FETCH NEXT FROM C_Loadplan_Add INTO @c_CurrentLoad, @c_LPStatus, @c_FinalizeFlag, @c_EditWho
   END -- While 1=1
   CLOSE C_Loadplan_Add
   DEALLOCATE C_Loadplan_Add
END

-- (MC03) - S  
/********************************************************/  
/* Interface Trigger Points Calling Process - (Start)   */  
/********************************************************/  
IF @n_continue = 1 OR @n_continue = 2   
BEGIN  
   /*      
   DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT INS.LoadKey, OH.StorerKey
   FROM   INSERTED INS 
   JOIN   LoadPlanDetail LD WITH (NOLOCK)    ON INS.LoadKey = LD.LoadKey  
   JOIN   Orders OH WITH (NOLOCK)            ON LD.OrderKey = OH.OrderKey  
   JOIN   ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = OH.StorerKey  
   WHERE  ITC.SourceTable = 'LOADPLAN'  
   AND    ITC.sValue      = '1'       

   OPEN Cur_TriggerPoints  
   FETCH NEXT FROM Cur_TriggerPoints INTO @c_LoadKey, @c_Storerkey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      EXECUTE dbo.isp_ITF_ntrLoadPlan 
                 @c_TriggerName    = 'ntrLoadPlanUpdate'
               , @c_SourceTable    = 'LOADPLAN'  
               , @c_Storerkey      = @c_Storerkey
               , @c_LoadKey        = @c_LoadKey  
               , @b_ColumnsUpdated = @b_ColumnsUpdated    
               , @b_Success        = @b_Success   OUTPUT  
               , @n_err            = @n_err       OUTPUT  
               , @c_errmsg         = @c_errmsg    OUTPUT  

      FETCH NEXT FROM Cur_TriggerPoints INTO @c_LoadKey, @c_Storerkey
   END -- WHILE @@FETCH_STATUS <> -1  
   CLOSE Cur_TriggerPoints  
   DEALLOCATE Cur_TriggerPoints  

   DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT INS.LoadKey, OH.StorerKey
   FROM   INSERTED INS 
   JOIN   LoadPlanDetail LD WITH (NOLOCK)    ON INS.LoadKey = LD.LoadKey  
   JOIN   Orders OH WITH (NOLOCK)            ON LD.OrderKey = OH.OrderKey    
   JOIN   ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = 'ALL'  
   JOIN   StorerConfig STC WITH (NOLOCK)     ON OH.StorerKey = STC.StorerKey AND STC.ConfigKey = ITC.ConfigKey AND STC.SValue = '1'   
   WHERE  ITC.SourceTable = 'LOADPLAN'  
   AND    ITC.sValue      = '1'        

   OPEN Cur_TriggerPoints  
   FETCH NEXT FROM Cur_TriggerPoints INTO @c_LoadKey, @c_Storerkey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      EXECUTE dbo.isp_ITF_ntrLoadPlan  
                 @c_TriggerName    = 'ntrLoadPlanUpdate'
               , @c_SourceTable    = 'LOADPLAN'  
               , @c_Storerkey      = @c_Storerkey
               , @c_LoadKey        = @c_LoadKey  
               , @b_ColumnsUpdated = @b_ColumnsUpdated    
               , @b_Success        = @b_Success   OUTPUT  
               , @n_err            = @n_err       OUTPUT  
               , @c_errmsg         = @c_errmsg    OUTPUT  

      FETCH NEXT FROM Cur_TriggerPoints INTO @c_LoadKey, @c_Storerkey
   END -- WHILE @@FETCH_STATUS <> -1  
   CLOSE Cur_TriggerPoints  
   DEALLOCATE Cur_TriggerPoints 
   */

   --(MC04) - S
   DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT INS.LoadKey, OH.StorerKey
   FROM   INSERTED INS 
   JOIN   LoadPlanDetail LD WITH (NOLOCK) ON INS.LoadKey = LD.LoadKey  
   JOIN   Orders OH WITH (NOLOCK)         ON LD.OrderKey = OH.OrderKey  

   OPEN Cur_TriggerPoints  
   FETCH NEXT FROM Cur_TriggerPoints INTO @c_LoadKey, @c_Storerkey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN

      SET @c_Proceed = 'N'

      IF EXISTS ( SELECT 1 
   	            FROM  ITFTriggerConfig ITC WITH (NOLOCK)       
   	            WHERE ITC.StorerKey   = @c_Storerkey
   	            AND   ITC.SourceTable = 'LOADPLAN'  
                  AND   ITC.sValue      = '1' )
      BEGIN
         SET @c_Proceed = 'Y'           
      END

      -- For OTMLOG StorerKey = 'ALL'
   	IF EXISTS ( SELECT 1 
   	            FROM  StorerConfig STC WITH (NOLOCK)        
   	            WHERE STC.StorerKey = @c_Storerkey 
   	            AND   STC.SValue    = '1' 
   	            AND   EXISTS(SELECT 1 
                               FROM  ITFTriggerConfig ITC WITH (NOLOCK)
   	                         WHERE ITC.StorerKey   = 'ALL' 
   	                         AND   ITC.SourceTable = 'LOADPLAN'  
                               AND   ITC.sValue      = '1' 
                               AND   ITC.ConfigKey = STC.ConfigKey ) )
      BEGIN                  
         SET @c_Proceed = 'Y'                          	
      END       

      IF @c_Proceed = 'Y'
      BEGIN

         --(MC05) - S
         SET @c_ColumnsUpdated = ''

         IF UPDATE(Status) OR @c_StatusUpdated = 'Y' 
         BEGIN
            IF @c_ColumnsUpdated = ''
            BEGIN
               SET @c_ColumnsUpdated = 'Status'
            END
            ELSE
            BEGIN
               SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + 'Status'
            END
         END

         /*
         SET @c_ColumnsUpdated = ''    

         DECLARE Cur_ColUpdated CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT COLUMN_NAME FROM dbo.fnc_GetUpdatedColumns('LOADPLAN', @b_ColumnsUpdated) 
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
         */
         --(MC05) - E

         EXECUTE dbo.isp_ITF_ntrLoadPlan  
                    @c_TriggerName    = 'ntrLoadPlanUpdate'
                  , @c_SourceTable    = 'LOADPLAN'  
                  , @c_Storerkey      = @c_Storerkey
                  , @c_LoadKey        = @c_LoadKey  
                  --, @b_ColumnsUpdated = @b_ColumnsUpdated   
                  , @c_ColumnsUpdated = @c_ColumnsUpdated                           
                  , @b_Success        = @b_Success   OUTPUT  
                  , @n_err            = @n_err       OUTPUT  
                  , @c_errmsg         = @c_errmsg    OUTPUT 
      END

      FETCH NEXT FROM Cur_TriggerPoints INTO @c_LoadKey, @c_Storerkey
   END -- WHILE @@FETCH_STATUS <> -1  
   CLOSE Cur_TriggerPoints  
   DEALLOCATE Cur_TriggerPoints 
   --(MC04) - E

END -- IF @n_continue = 1 OR @n_continue = 2   
/********************************************************/  
/* Interface Trigger Points Calling Process - (End)     */  
/********************************************************/  
-- (MC03) - E

-- tlting01
IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
BEGIN
   UPDATE LoadPlan  
   SET EditDate = GETDATE()
     , EditWho = SUSER_SNAME()
     , TrafficCop = NULL       
   FROM LoadPlan,INSERTED       
   WHERE LoadPlan.LoadKey=INSERTED.LoadKey      
   AND INSERTED.[status] in ( '9', 'C', 'CANC' )

   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT             

   IF @n_err <> 0      
   BEGIN      
      SELECT @n_continue = 3       
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72816      
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On LoadPlan. (ntrLoadPlanUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
   END      
END 

--IF @n_continue = 1 OR @n_continue = 2
--BEGIN
-- INSERT INTO T (status)
-- SELECT Status FrOM Inserted
--
--   IF EXISTS (SELECT 1 FROM INSERTED WITH (NOLOCK)
--              WHERE STATUS = '9' )
-- BEGIN
--
-- END
--END

/* #INCLUDE <TRMBOHU2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrLoadPlanUpdate'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

GO