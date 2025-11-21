SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*******************************************************************************/
/* Trigger: ntrOrderHeaderAdd                                                  */   
/* Creation Date:                                                              */
/* Copyright: IDS                                                              */
/* Written by:                                                                 */
/*                                                                             */
/* Purpose:   OrderHeader Add Trigger                                          */
/*                                                                             */
/* Usage:                                                                      */
/*                                                                             */
/* Called By: When records added into OrderHeader                              */
/*                                                                             */
/* PVCS Version: 1.4                                                           */
/*                                                                             */
/* Version: 5.4                                                                */
/*                                                                             */
/* Data Modifications:                                                         */
/* Date         Author     Ver  Purposes                                       */
/* 11-Sep-2002  RickyYee        Merge code from SOS, FBR and Performance       */
/*                              tuning from July 13th till Aug 23th            */
/* 04-Dec-2002  RickyYee        Changes make during V5 upgrade for IDSTH       */
/* 07-Mar-2003  RickyYee        New changes from Wally for Trigantic           */
/* 14-Apr-2003  Shong           To Skip all the trigger process when insert    */
/*                              the history records from Archive as user       */
/*                              request                                        */
/* 06-May-2003  RickyYee        To fixed the update of the userdefine05 when   */
/*                              he AutoUpdateOrderinfo configkey is turn on    */
/*                              and OWITF is turn on for externOrderKey value  */
/*                              and OWITF is turn off for StorerKey value      */
/* 27-Jun-2003  Vicky           Add configkey to control storer with Route     */
/*                              code to get value from StorerSODefault during  */
/*                              SO Import (SOS12053)                           */
/* 20-Nov-2003  YokeBeen        Modified for NSC Project (SOS15353)            */
/* 16-Feb-2004  YokeBeen        Modified for NSC Project (SOS20000)            */
/* 24-Feb-2004  YokeBeen        Modified for NSC Project (SOS20000)            */
/* 16-Apr-2004  RickyYee        Carrefour Crossdock impl. changes for the      */
/*                              Priority                                       */
/* 14-Jan-2005  RickyYee        Adding of C4 MY OrderType                      */
/* 01-Apr-2005  June            Add new configkey 'UpdateXDrouteinfo'          */
/*                              (SOS33929)                                     */
/* 04-Apr-2005  MaryVong        SG Maxxium - Shipment Order Confirm            */
/*                              (SOS30126)                                     */
/* 13-Jun-2005  June            SOS36159 - remove default zero in SOStatus     */
/* 27-Jun-2005  WTShong         Conver MIN to Cursor - Performance Tuning      */
/* 11-Jul-2005  WTShong         Thailand Report C4 EC Failed,Updating to Null  */
/* 12-Jul-2005  WTShong         EC Failed, Update Priority to NULL.            */
/* 14-Sep-2005  Vicky           SOS#39993 - Add in insertion of Status as      */
/*                              Key2 in Triganticlog table                     */
/* 25-Apr-2006  ONG01           SOS49862 - New ConfigKey 'SetPriority4SO'      */
/* 25-Jul-2006  YokeBeen        Set Default values for ORDERS.RoutingTool =    */
/*                              'Y' WHEN Configkey is either with              */
/*                              'TMSOutOrdHDR'/'TMSOutOrdDTL'and INSERTED's    */
/*                              RoutingTool is NULL.                           */
/*                              Insert record into TMSLog for Interface.       */
/*                              (SOS53821) - (YokeBeen01)                      */
/* 10-Nov-2006  YokeBeen        Remarked auto ORDERS.RoutingTool's update.     */
/*                              To add checking on this value for valid        */
/*                              records to be triggered into TMSLog.           */
/*                              All Interfaces must have the update for        */
/*                              ORDERS.RoutingTool based on the TMS Storer     */
/*                              Configkey setup in order to apply on this      */
/*                              TMS process. - (YokeBeen02)                    */
/* 21-Sep-2007  James           SOS80697 - add Key2 = 'A' into ispGenTMSLog    */
/*                              when Orders is newly added (TMSHK)             */
/*                              When configkey 'DefaultRoutingTool' is         */
/*                              turned on, default field RoutingTool = 'Y'     */
/* 11/8/2008    TLTING          string should be quoted ''                     */
/* 16-Jun-2009  Rick Liew       SOS96737 -- Reopen the StorerConfig            */
/* 17-Jul-2009  SHONG           SOS141432 - Enable DefaultRoutingTool in       */
/*                              Consignee Level                                */
/* 10-Sep-2009  TLTING     1.3  SOS146709 Set Trigantic intf mandatory         */
/*                              (tlting01)                                     */
/* 03-Nov-2009  TLTING     1.4  Orders. set Priority '5'                       */
/* 03-Nov-2010  MCTang     1.4  FBR#209302 - Added new trigger point for       */
/*                              upon new order insertion to interface          */
/*                              with Configkey = "SOADDLOG". - (MC01)          */
/* 24-FEB-2012  YTWan      1.5  SOS#236323:Default Orders.Userdefine08 base on */
/*                              Storercfg = 'KITDSCPICK'. (Wan01)              */
/* 22-OCT-2012  ChewKP     1.6  SOS#257863 Bug Fix (ChewKP01)                  */
/* 29-Jan-2013  TLTING     1.7  Storerconfig turn Off trigantic (TLTING02)     */
/* 23-Apr-2013  NJOW01     1.8  276280-populate more fields into orders        */
/* *************************************************************************** */
/* 09-Oct-2013  YokeBeen   1.4  Base on PVCS SQL2005_Unicode version 1.3.      */
/*                              FBR#291603 Comment out "SHPADVMSF" to insert   */
/*                              records into TransmitLog2. - (YokeBeen03)      */
/* 18-Feb-2014  KTLow      1.9  FBR#299158 - Added new trigger point for       */
/*                              upon new order insertion to interface          */
/*                              with Configkey = "WSCRSOADD". - (KT01)         */
/* 12-Sep-2014  TLTING     2.1  Doc Status Tracking Log TLTING03               */
/* 24-Nov-2014  NJOW02     2.2  325550-AutoUpdateOrderinfo=2 will update billto*/
/*                              if c_address1 is not null.                     */
/* 23-Apr-2015  MCTang     2.3  Enhance Generaic Trigger Interface (MC02)      */
/* 11-May-2015  TLTING     2.3  Disable Trigantics                             */
/* 20-May-2015  MCTang     2.3  Enhance Generaic Trigger Interface II (MC02)   */
/* 11-Jun-2015  TLTING     2.4  Auto Insert OrderInfor                         */
/* 02-OCT-2015  NJOW03     2.5  354034 - call custom stored proc               */
/* 15-JAN-2016  Leong      2.6  SOS360858 - Remove NonTRIGANTIC configkey.     */
/* 23-May-2018  Shong      2.7  Check RoutingTool before update (SWT01)        */
/* 04-Sep-2018  SWT02      2.8  Performance Tuning                             */
/* 29-Sep-2018  TLTING     2.9  remove update row lock                         */
/* 10-May-2020  SWT03      3.0  Restructure the loop and logic                 */ 
/* 16-Dec-2020  TLTING05   3.1  WMS-15510 tracking DSTORSSOSTATUS              */ 
/*******************************************************************************/

CREATE TRIGGER [dbo].[ntrOrderHeaderAdd]
ON  [dbo].[ORDERS]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success                 INT -- Populated by calls to stored procedures - was the proc successful?
          ,@n_err                     INT -- Error number returned by stored procedure or this trigger
          ,@n_err2                    INT -- For Additional Error Detection
          ,@c_errmsg                  NVARCHAR(250) -- Error message returned by stored procedure or this trigger
          ,@n_continue                INT
          ,@n_starttcnt               INT -- Holds the current transaction count
          ,@c_preprocess              NVARCHAR(250) -- preprocess
          ,@c_pstprocess              NVARCHAR(250) -- post process
          ,@n_cnt                     INT
          ,@c_Authority_soaddlog      NVARCHAR(1) -- (MC01)
          ,@c_Authority_wscrsoadd     NVARCHAR(1) -- (KT01)
          ,@c_ECOM_Orders             CHAR(1)='N'
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   
   DECLARE @c_Facility               NVARCHAR(5)=''
          ,@c_StorerKey              NVARCHAR(15)
          ,@c_OrdStatus              NVARCHAR(1)=''
          ,@c_OrderKey               NVARCHAR(10)=''  
          ,@c_Authority_tms          NVARCHAR(1)= '0'
          ,@n_TMSFleetWise           INT
          ,@c_ConsigneeKey           NVARCHAR(15)=''
          ,@c_OrderType              NVARCHAR(10)=''  
          ,@c_Authority_OrderI       NCHAR(1)= '0'
          ,@c_Route                  NVARCHAR(10)=''  
          ,@c_NIKEREGITF             NVARCHAR(1)= '0'
          ,@c_Tablename              NVARCHAR(30)=''
          ,@c_Authority_DSTORSSOSTATUS NVARCHAR(1)= '0'
          ,@c_OrdSOStatus            NVARCHAR(10)= ''

   -- To Skip all the trigger process when Insert the history records from Archive as user request                    
   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4 
   END                  

   --NJOW03
   IF @n_continue=1 or @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED i
                 JOIN storerconfig s WITH (NOLOCK) ON  i.StorerKey = s.StorerKey
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'OrdersTrigger_SP')
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

         EXECUTE dbo.isp_OrdersTrigger_Wrapper
                   'INSERT'  --@c_Action
                 , @b_Success  OUTPUT
                 , @n_Err      OUTPUT
                 , @c_ErrMsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrOrderHeaderAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END

         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END


   /********************************************************/
   /* Interface Trigger Points Calling Process - (Start)   */
   /********************************************************/
   --MC02 - S
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN

      DECLARE Cur_Itf_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT  DISTINCT INS.OrderKey
      FROM    INSERTED INS
      JOIN    ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey
      WHERE   ITC.SourceTable = 'ORDERS'
      AND     ITC.sValue      = '1'
      UNION
      SELECT DISTINCT IND.OrderKey
      FROM   INSERTED IND
      JOIN   ITFTriggerConfig ITC WITH (NOLOCK)
      ON     ITC.StorerKey   = 'ALL'
      JOIN   StorerConfig STC WITH (NOLOCK)
      ON     STC.StorerKey   = IND.StorerKey AND STC.ConfigKey = ITC.ConfigKey AND STC.SValue = '1'
      WHERE  ITC.SourceTable = 'ORDERS'
      AND    ITC.sValue      = '1'

      OPEN Cur_Itf_TriggerPoints
      FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_OrderKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         EXECUTE dbo.isp_ITF_ntrOrderHeader
                  @c_TriggerName    = 'ntrOrderHeaderAdd'
                , @c_SourceTable    = 'ORDERS'
                , @c_OrderKey       = @c_OrderKey
                , @c_ColumnsUpdated = ''
                , @b_Success        = @b_Success OUTPUT
                , @n_err            = @n_err    OUTPUT
                , @c_errmsg         = @c_errmsg  OUTPUT

         FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_OrderKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_Itf_TriggerPoints
      DEALLOCATE Cur_Itf_TriggerPoints

   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE ORD_ADD_CUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Facility,
             StorerKey,
             Status,       
             OrderKey,     
             ConsigneeKey, 
             TYPE,         
             ISNULL([Route],''),
             ISNULL(SOStatus,'')
        FROM INSERTED

      OPEN ORD_ADD_CUR

      FETCH NEXT FROM ORD_ADD_CUR INTO @c_Facility, @c_StorerKey, @c_ordstatus, @c_OrderKey, @c_ConsigneeKey, @c_OrderType, @c_Route
                        , @c_OrdSOStatus
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- TLTING03
         --------------------------------------------
         --- STSORDERS
         --------------------------------------------         
         EXEC ispGenDocStatusLog 'STSORDERS', @c_StorerKey, @c_OrderKey, '', '',@c_ordstatus
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62302   
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable to insert DocStatusTrack (ntrOrderHeaderAdd) ( SQLSvr MESSAGE=' 
            + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END

         --tlting05
         --------------------------------------------
         --- DSTORSSOSTATUS
         --------------------------------------------    
         SET @c_Authority_DSTORSSOSTATUS = '0'
         IF @n_continue=1 OR @n_continue = 2
         BEGIN
            SELECT @b_success = 0
            EXECUTE dbo.nspGetRight  '',       -- Facility
                     @c_StorerKey,             -- Storer
                     '',                       -- Sku
                     'DSTORSSOSTATUS',               -- ConfigKey
                     @b_success                OUTPUT,
                     @c_Authority_DSTORSSOSTATUS     OUTPUT,
                     @n_err                    OUTPUT,
                     @c_errmsg                 OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63901
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (DSTORSSOSTATUS) Failed (ntrOrderHeaderAdd) ( SQLSvr MESSAGE='
                                + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            ELSE
            BEGIN
               IF @c_Authority_DSTORSSOSTATUS = '1' AND @c_OrdSOStatus <> ''
               BEGIN
                  EXEC ispGenDocStatusLog 'DSTORSSOSTATUS', @c_StorerKey, @c_OrderKey, '', '',@c_OrdSOStatus
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                  
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END -- @@c_Authority_DSTORSSOSTATUS = '1'
            END -- IF @b_success = 1
         END -- IF @n_continue=1 OR @n_continue = 2

         
         --------------------------------------------
         --- OrderInfo
         --------------------------------------------         
         -- tlting04  - Mercury-Auto create data in table Orderinfo
         SET @c_Authority_OrderI='0'

         EXECUTE nspGetRight @c_Facility,
                             @c_StorerKey,   -- Storer
                             NULL,           -- No Sku in this Case
                             'OrderInfo',   -- ConfigKey
                             @b_success          output,
                             @c_Authority_OrderI output,
                             @n_err              output,
                             @c_errmsg           output

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            IF @c_Authority_OrderI = '1' 
            BEGIN
      	      -- SWT02
               IF  NOT EXISTS ( SELECT 1 FROM OrderInfo (NOLOCK) WHERE OrderInfo.OrderKey = @c_OrderKey )
               BEGIN
                  INSERT INTO OrderInfo (OrderKey) VALUES (@c_OrderKey)
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0 OR @n_cnt = 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62318   
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed on OrderInfo. (ntrOrderHeaderAdd) ( SQLSvr MESSAGE=' 
                              + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END         	
               END      	
            END
         END
         -- TLTING04 end

         -- (YokeBeen01) - Start
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT  @c_Tablename = ''

            -- (YokeBeen02) - Start
            IF EXISTS ( SELECT 1 
                        FROM INSERTED AS ORD 
                        JOIN StorerConfig WITH (NOLOCK) ON ( StorerConfig.StorerKey = ORD.StorerKey ) 
                                       AND StorerConfig.ConfigKey IN ('TMSOutOrdHDR','TMSOutOrdDTL') 
                                       AND StorerConfig.sValue = '1'
                        WHERE ORD.OrderKey = @c_OrderKey                         
                        AND ORD.RoutingTool = 'Y' )
            BEGIN
               SELECT TOP 1 
                  @c_Tablename = ConfigKey
               FROM INSERTED AS ORD 
               JOIN StorerConfig (NOLOCK) ON StorerConfig.StorerKey = ORD.StorerKey
                                          AND StorerConfig.ConfigKey IN ('TMSOutOrdHDR','TMSOutOrdDTL') 
                                          AND StorerConfig.sValue = '1'
               WHERE ORD.OrderKey = @c_OrderKey
               
               --check wether configkey has been setup for 'TMS_Fleetwise'
                  SET @c_Authority_tms = ''

                  EXEC nspGetRight @c_Facility,
                                   @c_StorerKey,   -- Storer
                                   NULL,           -- No Sku in this Case
                                   'TMS_Fleetwise',   -- ConfigKey
                                   @b_success          output,
                                   @c_Authority_tms    output,
                                   @n_err              output,
                                   @c_errmsg           output

                   IF @c_Authority_tms = '1'
                     SET @n_TMSFleetWise = 1 -- has been setup
                   ELSE
                     SET @n_TMSFleetWise = 0

                  --if TMS_Fleetwise storerconfig turned on,
                  --need to make sure orders.userdefine08 <> 'Y' or orders.userdefine08 <> '4' Then insert TMSLOG
                  IF @n_TMSFleetWise = 1
                  BEGIN
                     IF NOT EXISTS (SELECT 1 
                                    FROM INSERTED AS ORD 
                                    WHERE ORD.OrderKey = @c_OrderKey
                                    AND   ORD.USERDEFINE08 IN ('Y', '4'))
                     BEGIN
                        -- Insert records into TMSLog table
                        -- SOS80697 Add Key2 = A for TMSHK (James)
                        EXEC ispGenTMSLog @c_Tablename, @c_OrderKey, 'A', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=68000   
                           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into TMSLog Failed (ntrOrderHeaderAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                        END
                     END
                  END
                  ELSE  --Not TMS_Fleetwise
                  BEGIN
                     -- Insert records into TMSLog table
                     -- SOS80697 Add Key2 = A for TMSHK (James)
                     EXEC ispGenTMSLog @c_Tablename, @c_OrderKey, 'A', @c_StorerKey, ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=68000   
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into TMSLog Failed (ntrOrderHeaderAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                     END
                  END
            END -- Valid StorerConfig check
            -- (YokeBeen02) - End
         END
         -- (YokeBeen01) - End


            -- (MC01) - Start
         IF @n_continue=1 OR @n_continue = 2
         BEGIN
            SELECT @b_success = 0
            EXECUTE dbo.nspGetRight  '',       -- Facility
                     @c_StorerKey,             -- Storer
                     '',                       -- Sku
                     'SOADDLOG',               -- ConfigKey
                     @b_success                OUTPUT,
                     @c_Authority_soaddlog     OUTPUT,
                     @n_err                    OUTPUT,
                     @c_errmsg                 OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63801
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (SOADDLOG) Failed (ntrOrderHeaderAdd) ( SQLSvr MESSAGE='
                                + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            ELSE
            BEGIN
               IF @c_Authority_soaddlog = '1'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3 'SOADDLOG', @c_OrderKey, @c_OrderType, @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END -- @c_Authority_soaddlog = '1'
            END -- IF @b_success = 1
         END -- IF @n_continue=1 OR @n_continue = 2
         -- (MC01) - End

         -- (KT01) - Start
         IF @n_continue=1 OR @n_continue = 2
         BEGIN
            SELECT @b_success = 0
            EXECUTE dbo.nspGetRight  '',       -- Facility
                     @c_StorerKey,             -- Storer
                     '',                       -- Sku
                     'WSCRSOADD',              -- ConfigKey
                     @b_success                OUTPUT,
                     @c_Authority_wscrsoadd    OUTPUT,
                     @n_err                    OUTPUT,
                     @c_errmsg                 OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63801
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (WSCRSOADD) Failed (ntrOrderHeaderAdd) ( SQLSvr MESSAGE='
                                + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            ELSE
            BEGIN
               IF @c_Authority_wscrsoadd = '1'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3 'WSCRSOADD', @c_OrderKey, '', @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END -- @c_Authority_soaddlog = '1'
            END -- IF @b_success = 1
         END -- IF @n_continue=1 OR @n_continue = 2
         -- (KT01) - End


         -- Added by YokeBeen on 14-Nov-2003 - Nike Regional Interface (NSC Project)
         -- (SOS#15353) - 'R' - Delivery Received. Validate the delivery note has been loaded into the WMS.
         IF @n_continue=1 OR @n_continue = 2
         BEGIN
            SELECT @c_NIKEREGITF = '0'
            SELECT @b_success = 0

            EXECUTE nspGetRight NULL,           -- Facility
                                 @c_StorerKey,   -- Storer
                                 NULL,           -- No Sku in this Case
                                 'NIKEREGITF',   -- ConfigKey
                                 @b_success          output,
                                 @c_NIKEREGITF       output,
                                 @n_err              output,
                                 @c_errmsg           output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62314  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retrieve Failed On GetRight. (ntrOrderHeaderAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            ELSE IF @c_NIKEREGITF = '1'
            BEGIN
               -- Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
               -- Changed to trigger records into NSCLog table with 'NSCKEY'.
               EXEC ispGenNSCLog 'NIKEREGDSR', @c_OrderKey, '', @c_StorerKey, ''
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62315   
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable to obtain nsclogkey (ntrOrderHeaderAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            End -- IF @c_NIKEREGITF = '1'
            -- End Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
         END
         -- End - (SOS#15353) - NSC Project         
-------------------------------            
         FETCH NEXT FROM ORD_ADD_CUR INTO @c_Facility, @c_StorerKey, @c_ordstatus, @c_OrderKey, @c_ConsigneeKey, @c_OrderType, @c_Route 
                                       , @c_OrdSOStatus
      END -- While Order Record
      CLOSE ORD_ADD_CUR
      DEALLOCATE ORD_ADD_CUR
      -- END -- SOS360858
   END         

                       
   /********************************************************/
   /* Interface Trigger Points Calling Process - (End)     */
   /********************************************************/

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
      execute nsp_logerror @n_err, @c_errmsg, 'ntrOrderHeaderAdd'
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

END -- End Procedure

GO