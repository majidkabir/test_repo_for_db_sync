SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Trigger:  ntrMBOLDetailAdd                                              */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:  Trigger point upon any insert MBOLDetail                      */  
/*                                                                         */  
/* Input Parameters:                                                       */  
/*                                                                         */  
/* Output Parameters:  None                                                */  
/*                                                                         */  
/* Return Status:  None                                                    */  
/*                                                                         */  
/* Usage:                                                                  */  
/*                                                                         */  
/* Local Variables:                                                        */  
/*                                                                         */  
/* Called By: When records updated                                         */  
/*                                                                         */  
/* PVCS Version: 1.12                                                      */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author Ver.  Purposes                                      */  
/* 22-Jul-2004  SHONG        Convert SELECT MIN to Cursor Loop             */  
/* 17-Oct-2005  Vicky        SOS#41907 - To Fix the Casecnt so that it's   */  
/*                                       tally with Loadplan               */  
/* 23-Mar-2006  SHONG        Performance Tuning (SWT_Perf_001)             */  
/* 23-Nov-2007  SHONG        Not Allow to populate Order# into more then 1 */  
/*                           MBOL (SOS92506)                               */  
/* 11-May-2009  NJOW01 1.1   SOS#118352                                    */  
/*                           Populate Carton count by order to MBOL detail */  
/* 26-Jun-2009  NJOW02 1.2   Change calculate total carton by using        */  
/*                           distinct count packdetail.cartonno            */  
/* 17-Aug-2009  SHONG  1.3   SOS#140791 Default Loadplan.TotCtnWeight and  */  
/*                           TotCtnCube                                    */  
/* 05-May-2010  NJOW01 1.4   168916 - update total carton to mbol          */  
/*                           depend on mbol.userdefine09                   */  
/* 07-Apr-2011  NJOW03 1.5   Calculate total carton using distinct labelno */  
/*                           to cater for multi ps per order scenario      */  
/* 14-Mar-2012  KHLim011.6   Update EditDate of several tables             */  
/* 06-APR-2012  YTWan  1.7   SOS#238876-ReplaceUSAMBOL. Calculate          */  
/*                           NoofCartonPacked. (Wan01)                     */  
/* 30-Apr-2012  SHONG  1.8   CustCnt Should using Count Distinct Consignee */  
/*                           Cater ConsoOrderKey                           */  
/* 23-May-2012  SHONG  1.8   Do Not Calculate CtnCnt When TrafficCop = '1' */  
/* 24-May-2012  Leong  1.8   SOS# 245519 - Bug Fix                         */  
/* 07-Nov-2012  KHLim  1.9   DM integrity - Update EditDate  (KH01)        */  
/* 20-Nov-2013  TLTING 1.10  Nolock hints (tlting01)                       */  
/* 21-Sep-2015  ChewKP 1.11  Auto Generate MBOLLineDetail.MBOLLineNumber   */  
/*                           when inserted = '00000'  (ChewKP01)           */  
/* 28-JUL-2017  Wan02  1.12   WMS-1916 - WMS Storerconfig for Copy         */  
/*                           totalcarton to ctncnt1 in mboldetail          */  
/* 17-Aug-2017  TLTING 1.13  Bug fix - update archiveCop                   */  
/* 14-Jan-2020  SHONG  1.14  Update OrderDetail With Cursor Loop           */
/* 28-May-2020  Shong  1.15  WMS-13444 Auto Create POD record after MBOL   */  
/*                           creation  (SWT01)                             */  
/* 10-Dec-2020  TLTING02 1.16  Performance tune                            */  
/***************************************************************************/  
CREATE TRIGGER [dbo].[ntrMBOLDetailAdd]  
ON  [dbo].[MBOLDETAIL]  
FOR INSERT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_debug int  
   SELECT @b_debug = 0  
   DECLARE  
             @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?  
   ,         @n_err                int       -- Error number returned by stored procedure or this trigger  
   ,         @n_err2 int              -- For Additional Error Detection  
   ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
   ,         @n_Continue int  
   ,         @n_starttcnt int                -- Holds the current transaction count  
   ,         @c_preprocess NVARCHAR(250)         -- preprocess  
   ,         @c_pstprocess NVARCHAR(250)         -- post process  
   ,         @n_cnt              INT  
   ,         @c_storerkey        NVARCHAR(15)  
   ,         @c_authority        NVARCHAR(1)  
   ,         @c_POD_Authority    NVARCHAR(1) = '0'   -- (SWT01)  
   ,         @c_POD_Option01     NVARCHAR(20) = ''   -- (SWT01)  
   ,         @c_PODXDeliverDate  NVARCHAR(1) = '0'   -- (SWT01)  
   ,         @c_Facility         NVARCHAR(5)         -- (SWT01)  
  
   SELECT @n_Continue=1, @n_starttcnt=@@TRANCOUNT  
   /* #INCLUDE <TRMBODA1.SQL> */  
  
   DECLARE @c_InvoiceStatus NVARCHAR(10),  
           @d_DeliveryDate  datetime,  
           @c_PCM           NVARCHAR(12),  
           @c_Reason        NVARCHAR(60),  
           @c_MBOLKey       NVARCHAR(10),  
           @c_OtherMBOL     NVARCHAR(10),  
           @c_OrderKey      NVARCHAR(10),  
           @c_OrderLineNumber NVARCHAR(5)  
  
   DECLARE  @n_casecnt       int,  
            @n_palletcnt     int,  
            @n_weight        decimal(15, 4),  
            @n_cube          decimal(15, 4),  
            @n_custcnt       int,  
            @c_PrevLoadKey   NVARCHAR(10),  
            @c_VoyageNumber  NVARCHAR(30),  
            @c_LoadKey       NVARCHAR(10),  
            @f_TotCtnWeight  float,  
            @f_TotCtnCube    float,  
            @cLabelLine     NVARCHAR(5)    
  
   DECLARE @n_TtlCnts int --NJOW01 SOS#118352  
  
   IF @n_Continue=1 or @n_Continue=2  
   BEGIN  
      IF EXISTS(SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')  
         SELECT @n_Continue = 4  
   END  
   -- End  
  
   IF @n_Continue=1 or @n_Continue=2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM MBOL with (NOLOCK), INSERTED   -- tlting01  
                 WHERE MBOL.MBOLKey = INSERTED.MBOLKey  
                 AND MBOL.Status = '9')  
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @n_err=72900  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': MBOL.Status = ''SHIPPED''. UPDATE rejected. (ntrMBOLDetailAdd)'  
      END  
   END  
  
   --(Wan02) - START  
   IF @n_continue=1 or @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM INSERTED i  
                 JOIN ORDERS       O WITH (NOLOCK) ON (I.OrderKey = O.OrderKey)  
                 JOIN storerconfig s WITH (NOLOCK) ON (O.storerkey = s.storerkey)  
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue  
                 WHERE  s.configkey = 'MBOLDetailTrigger_SP')  
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
  
         EXECUTE dbo.isp_MBOLDetailTrigger_Wrapper  
                   'INSERT'  --@c_Action  
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT  
                 , @c_ErrMsg   OUTPUT  
  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrMBOLDetailAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  
         END  
  
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL  
            DROP TABLE #INSERTED  
  
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL  
            DROP TABLE #DELETED  
      END  
   END  
   --(Wan02) - END  
   -- (ChewKP01)   
   IF EXISTS (SELECT 1 FROM INSERTED WITH (NOLOCK) WHERE INSERTED.MBOLLineNumber = '00000')    
   BEGIN             
  
     
       SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( MBOLDETAIL.MBOLLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)    
       FROM MBOLDETAIL WITH (NOLOCK)    
       JOIN INSERTED WITH (NOLOCK) ON (MBOLDETAIL.MBOLKey = INSERTED.MBOLKey )   
     
       UPDATE MBOLDETAIL    
          SET MBOLLineNumber = @cLabelLine  
              ,TrafficCop = NULL   
       FROM INSERTED WITH (NOLOCK)    
       WHERE MBOLDetail.MBOLKey = INSERTED.MBOLKey    
       AND   MBOLDetail.OrderKey = INSERTED.OrderKey    
       --AND   PACKDETAIL.CartonNo = 0    
     
  
  
      IF EXISTS ( SELECT 1   
         FROM MBOLDetail (NOLOCK)   
         JOIN INSERTED WITH (NOLOCK) ON (MBOLDetail.MBOLKey = INSERTED.MBOLKey)    
         WHERE MBOLDetail.MBOLLineNumber = @cLabelLine  
         HAVING COUNT( DISTINCT MBOLDetail.MBOLLineNumber) > 1)   
      BEGIN  
         SELECT @n_err = 72613    
         SELECT @n_continue = 3    
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+ ': MBOLLineNumber repeated (ntrMBOLDetailAdd)'  
      END  
  
   
   END    
  
   -- Added for IDSV5 by June 26.Jun.02, (extract from IDSPH) *** Start  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      DECLARE C_OrderKey_Cursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LoadKey,      OrderKey, MBOLKey,      InvoiceStatus,  
                DeliveryDate, PCMNum,   ExternReason  
         FROM   INSERTED  
         ORDER BY LoadKey  
  
  
      OPEN C_OrderKey_Cursor  
  
      FETCH NEXT FROM C_OrderKey_Cursor INTO  
            @c_LoadKey, @c_OrderKey, @c_MBOLKey, @c_InvoiceStatus, @d_DeliveryDate,  
            @c_PCM, @c_Reason  
  
      WHILE @@FETCH_STATUS <> -1 AND ( @n_Continue = 1 OR @n_Continue = 2 )  
      BEGIN  
         SET @c_OtherMBOL = ''  
  
         SELECT @c_OtherMBOL = ISNULL(MBOLKey, '')  
         FROM   MBOLDetail WITH (NOLOCK)  
         WHERE  OrderKey = @c_OrderKey  
         AND    MBOLKey <> @c_MBOLKey  
  
         IF ISNULL(RTrim(@c_OtherMBOL), '') <> ''  
         BEGIN  
            SELECT @n_Continue = 3  
            SELECT @n_err=72613  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+' OrderKey ' + @c_OrderKey + ' Already Populate to MBOL# ' + @c_OtherMBOL  
            GOTO QUIT  
         END  
  
         IF @c_PrevLoadKey <> @c_LoadKey  
         BEGIN  
            SET @c_PrevLoadKey = @c_LoadKey  
  
            IF EXISTS(SELECT 1 FROM LoadPlan WITH (NOLOCK)  
                      WHERE LoadKey = @c_LoadKey AND (MBOLKey = '' OR MBOLKey IS NULL))  
            BEGIN  
               SET @f_TotCtnWeight = 0  
               SET @f_TotCtnCube   = 0  
  
               SELECT @f_TotCtnWeight = TotCtnWeight,  
                      @f_TotCtnCube   = TotCtnCube  
               FROM   LOADPLAN WITH (NOLOCK)  
               WHERE  LoadKey = @c_LoadKey  
  
               IF ISNULL(@f_TotCtnWeight,0) = 0 AND ISNULL(@f_TotCtnCube,0) = 0  
               BEGIN  
                  -- SOS#140791 Default Loadplan.TotCtnWeight  
                  IF NOT EXISTS(SELECT TOP 1 PickSlipNo FROM PACKHEADER WITH (NOLOCK)  
                                WHERE  LOADKEY = @c_LoadKey)  
                  BEGIN  
                     SELECT @f_TotCtnWeight = SUM(P.Qty * ISNULL(SKU.STDNETWGT,0)),  
                            @f_TotCtnCube   = SUM(P.Qty * ISNULL(SKU.STDCUBE,0))  
                     FROM   PICKDETAIL P WITH (NOLOCK)  
                     JOIN   LOADPLANDETAIL LP WITH (NOLOCK) ON (LP.OrderKey = P.OrderKey)  
                     JOIN   SKU WITH (NOLOCK) ON SKU.StorerKey =P.StorerKey AND SKU.SKU = P.SKU  
                     WHERE  LP.LoadKey = @c_LoadKey  
                  END  
               END  
  
               UPDATE LOADPLAN WITH (ROWLOCK)  
               SET MBOLKey = @c_MBOLKey,  
                   EditDate = GETDATE(), -- KHLim01  
                   TrafficCop = NULL,  
                   -- SOS#140791  
                   TotCtnCube = @f_TotCtnCube,  
                   TotCtnWeight = @f_TotCtnWeight  
               WHERE LoadKey = @c_LoadKey  
  
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_Continue = 3  
                  SELECT @n_err=72601  
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (ntrMBOLDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
                  GOTO QUIT  
               END  
            END  
         END -- IF @c_PrevLoadKey <> @c_LoadKey  
  
         SELECT @c_Storerkey = Storerkey  
              , @c_Facility = Facility  
         FROM   ORDERS WITH (NOLOCK)  
         WHERE  ORDERS.Orderkey = @c_OrderKey  
  
         SELECT @b_success = 0  
         Execute nspGetRight  
                 NULL,  -- facility  
                 @c_StorerKey,  -- Storerkey  
                 NULL,          -- Sku  
                 'ACSIE',       -- Configkey  
                 @b_success     output,  
                 @c_authority   output,  
                 @n_err         output,  
                 @c_errmsg      output  
  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_Continue = 3, @c_errmsg = 'ntrMBOLDetailAdd' + dbo.fnc_RTrim(@c_errmsg)  
         END  
         ELSE IF @c_authority = '1'  
         BEGIN  
            -- for ACSIE  
            -- WALLY 8.may.2001  
            -- mandatory fields based on invoice status  
            IF @c_InvoiceStatus = 'D' AND @d_DeliveryDate IS NULL  
            BEGIN  
               SELECT @n_Continue = 3  
               SELECT @n_err=72611  
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+' : ACTUAL DELIVERY DATE REQUIRED...'  
               GOTO QUIT  
            END  
            ELSE IF @c_InvoiceStatus = 'J' AND (@c_PCM IS NULL OR @c_PCM = '') AND (@c_Reason IS NULL OR @c_Reason = '')  
            BEGIN  
               SELECT @n_Continue = 3  
               SELECT @n_err=72611  
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+' : PCM NUMBER and REASON CODE REQUIRED...'  
               GOTO QUIT  
            END  
         END -- IF ACSIE @c_authority = '1'  
  
         IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey = @c_OrderKey  
                   AND (MBOLKey IS NULL OR MBOLKey = ''))  
         BEGIN  
            UPDATE ORDERS WITH (ROWLOCK)  
            SET MBOLKey = @c_MBOLKey,  
                EditDate = GETDATE(), -- KHLim01  
                TrafficCop = NULL  
            WHERE OrderKey = @c_OrderKey  
             AND (MBOLKey IS NULL OR MBOLKey = '')  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
         SELECT @n_Continue = 3  
               SELECT @n_err=72601  
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERS. (ntrMBOLDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            END  
         END  
           
         DECLARE CUR_ORDERLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT OrderLineNumber  
         FROM OrderDetail WITH (NOLOCK)   
         WHERE OrderKey = @c_OrderKey  
         AND (MBOLKey IS NULL OR MBOLKey = '')  
           
         OPEN CUR_ORDERLINE  
           
         FETCH FROM CUR_ORDERLINE INTO @c_OrderLineNumber  
           
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            UPDATE ORDERDETAIL WITH (ROWLOCK)  
                  SET MBOLKey = @c_MBOLKey,  
                      EditDate = GETDATE(),   
                      TrafficCop = NULL  
            WHERE OrderKey = @c_OrderKey   
            AND OrderLineNumber = @c_OrderLineNumber  
  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_Continue = 3  
               SELECT @n_err=72601  
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table OrderDetail. (ntrMBOLDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            END  
           
          FETCH FROM CUR_ORDERLINE INTO @c_OrderLineNumber  
         END  
           
         CLOSE CUR_ORDERLINE  
         DEALLOCATE CUR_ORDERLINE  
           
         -- NJOW01 SOS#118352-- Start  
          SET @n_TtlCnts = 0  
          SELECT @n_TtlCnts = COUNT(DISTINCT PACKDETAIL.LabelNo)   --NJOW02 / NJOW03  
          FROM PACKHEADER (NOLOCK)  
          JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)  
          WHERE PACKHEADER.Status = '9'  
          AND PACKHEADER.Orderkey = @c_orderkey  
  
          IF @n_TtlCnts > 0  
          BEGIN  
             UPDATE MBOLDETAIL WITH (ROWLOCK)  
                SET TotalCartons = @n_TtlCnts,  
                    EditDate = GETDATE(), -- KHLim01  
                    Trafficcop = NULL  
                WHERE Orderkey = @c_orderkey  
                AND MBOLKey = @c_MBOLKey  
                AND ISNULL(TotalCartons,0) = 0  -- usually using populate load plan / order function to insert  
  
              SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
              IF @n_err <> 0  
              BEGIN  
                 SELECT @n_Continue = 3  
                 SELECT @n_err=72611  
                 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table MBOLDetail. (ntrMBOLDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
              END  
  
              --(Wan01)  - START (open the remark)  
              IF (@n_Continue = 1 OR @n_Continue = 2) AND @n_cnt > 0  
              BEGIN  
                  UPDATE MBOL WITH (ROWLOCK)  
                  SET NoofCartonPacked = ISNULL(NoOfCartonPacked,0) + @n_TtlCnts  
                   , EditWho = SUSER_NAME()  
                   , EditDate = GETDATE()  
                   , Trafficcop = NULL  
                  WHERE MBOLKey = @c_MBOLKey  
  
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @n_err=72612  
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table MBOL. (ntrMBOLDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
                  END  
              END  
              --(Wan01)  - END (open the remark)  
           END -- IF @n_TtlCnts > 0  
           -- NJOW01 SOS#118352-- End  
  
            -- Generate POD Records Here................... (SWT01)  
            SET @b_success = 0  
            SET @c_POD_Option01=''  
            SET @c_POD_Authority = ''  
              
            EXECUTE nspGetRight   
                @c_Facility  = @c_Facility -- facility  
               ,@c_StorerKey = @c_StorerKey -- Storerkey -- SOS40271  
               ,@c_sku       = NULL         -- Sku  
               ,@c_ConfigKey = 'POD'        -- Configkey  
               ,@b_Success   = @b_success      OUTPUT  
               ,@c_authority = @c_POD_Authority OUTPUT  
               ,@n_err       = @n_err          OUTPUT  
               ,@c_errmsg    = @c_errmsg       OUTPUT  
               ,@c_Option1   = @c_POD_Option01 OUTPUT -- (SWT01)   
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'ntrMBOLDetailAdd' + RTRIM(@c_errmsg)  
            END  
            ELSE IF @c_POD_Authority = '1' AND @c_POD_Option01 = 'MBOLADD'  
            BEGIN   
               IF @b_debug = 1  
               BEGIN  
                  SELECT 'Insert Details of MBOL into POD Table'  
               END  
                 
               IF NOT EXISTS ( SELECT 1 FROM POD WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND MBOLKey = @c_MBOLKey)  
               BEGIN  
  
                  SET @c_PODXDeliverDate = '0'  
                  SET @b_success = 0  
                  EXECUTE nspGetRight  
                        @c_facility, -- facility  
                        @c_storerkey, -- Storerkey -- SOS40271  
                        null,         -- Sku  
                        'PODXDeliverDate',  -- Configkey  
                        @b_success           OUTPUT,  
                        @c_PODXDeliverDate   OUTPUT,  
                        @n_err               OUTPUT,  
                        @c_errmsg            OUTPUT  
                                      
                  INSERT INTO POD  
                              (MBOLKey,         MBOLLineNumber,   LoadKey,    ExternLoadKey,       
                               OrderKey,        BuyerPO,          ExternOrderKey,  
                               InvoiceNo,       status,           ActualDeliveryDate,  
                               InvDespatchDate, poddef08,         Storerkey,    
                               SpecialHandling, TrackCol01)       
                  SELECT   MBOLDetail.MBOLKey,  
                           MBOLDetail.MBOLLineNumber,  
                           ORDERS.LoadKey,  
                           ISNULL(LOADPLAN.ExternLoadKey, ''),     
                           ORDERS.OrderKey,  
                           ORDERS.BuyerPO,  
                           ORDERS.ExternOrderKey,  
                           ORDERS.InvoiceNo,     
                           '0',  
                           CASE WHEN @c_PODXDeliverDate = '1' THEN NULL ELSE GETDATE() END,  
                           InvDespatchDate=GETDATE(),  
                           PODDef08=ISNULL(MBOLDetail.its,''),    
                           ORDERS.Storerkey,  
                           ORDERS.SpecialHandling,   
                           TrackCol01 =''              
                    FROM MBOLDetail WITH (NOLOCK)  
                    JOIN ORDERS ON (MBOLDetail.OrderKey = ORDERS.OrderKey)  
                    LEFT JOIN LOADPLAN LOADPLAN WITH (NOLOCK) ON (LOADPLAN.LoadKey = ORDERS.LoadKey)     
                    WHERE ORDERS.OrderKey = @c_OrderKey  
                      AND MBOLDetail.MBOLKey = @c_MBOLKey    
  
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807  
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))  
                                      + ': Insert Failed On Table POD. (ntrMBOLDetailAdd)'  
                                      + ' ( SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg), '') + ' ) '  
                  END  
               END  
            END -- POD Authority = 1 -- (SWT01)  
           
           FETCH NEXT FROM C_OrderKey_Cursor INTO  
               @c_LoadKey, @c_OrderKey, @c_MBOLKey, @c_InvoiceStatus, @d_DeliveryDate,  
               @c_PCM, @c_Reason  
      END -- While Loop  
      CLOSE C_OrderKey_Cursor  
      DEALLOCATE C_OrderKey_Cursor  
   END  
  
  
   /**** To Calculate Weight, Cube, Pallet, Case and Customer Cnt ****/  
   IF @n_Continue = 1 or @n_Continue = 2  
   BEGIN  
      SELECT @c_MBOLKey = ''  
  
      DECLARE C_trMBOLDetail CURSOR FAST_FORWARD READ_ONLY FOR  
         SELECT  INSERTED.MBOLKey,  
                 SUM(INSERTED.Weight),  
                 SUM(INSERTED.Cube),  
                 COUNT(DISTINCT O.ConsigneeKey)  
         FROM  INSERTED  
         JOIN ORDERS O WITH (NOLOCK) ON (O.OrderKey = INSERTED.OrderKey)  
         GROUP BY INSERTED.MBOLKey  
         ORDER BY INSERTED.MBOLKey  
  
      OPEN C_trMBOLDetail  
  
      FETCH NEXT FROM C_trMBOLDetail INTO @c_MBOLKey, @n_weight, @n_cube, @n_custcnt  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF dbo.fnc_RTrim(@c_MBOLKey) IS NULL OR dbo.fnc_RTrim(@c_MBOLKey) = ''  
            BREAK  
  
         SET @c_VoyageNumber = ''  

         --tlting02
         SELECT @c_VoyageNumber = IsNULL(MAX(LoadPlan.Route), ' ') -- SOS# 245519  
         FROM  LoadPlan (NOLOCK)  
         WHERE exists  ( SELECT   1 FROM  MBOLDETAIL MD WITH (NOLOCK)   
                        JOIN Orders O (NOLOCK) ON O.Orderkey =  MD.OrderKey
                        WHERE  MD.MBOLKey = @c_MBOLKey 
                        AND O.LoadKey = LoadPlan.LoadKey  )  
                       

         --SELECT @c_VoyageNumber = IsNULL(MAX(LoadPlan.Route), ' ') -- SOS# 245519  
         --FROM  LoadPlan (NOLOCK)  
         --WHERE EXISTS(SELECT 1 FROM LoadPlanDetail lpd WITH (NOLOCK)  
         --            JOIN  MBOLDETAIL MD WITH (NOLOCK) ON MD.OrderKey = lpd.OrderKey  
         --            WHERE lpd.LoadKey = LoadPlan.LoadKey  
         --              AND MD.MBOLKey = @c_MBOLKey)  
   
  
         -- Modified By Vicky on 17th Oct 2005  
         -- SOS #41907 - To fix the casecnt so that tally with loadplan  
         SELECT @n_casecnt = SUM(CASE WHEN PACK.CASECNT = 0 THEN 0  
                                 ELSE (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) / (PACK.CaseCnt)  
                                 END),  
               @n_palletcnt = SUM((ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) / (CASE WHEN PACK.Pallet = 0  
                                                                                          THEN 1  
                                                                                          ELSE PACK.Pallet  
                                                                                          END))  
         FROM  ORDERDETAIL (NOLOCK), INSERTED, PACK (NOLOCK)  
         WHERE ORDERDETAIL.OrderKey = INSERTED.OrderKey  
         AND   ORDERDETAIL.Packkey = PACK.Packkey  
         AND   INSERTED.MBOLKey = @c_MBOLKey  
  
         IF @n_casecnt = NULL SELECT @n_casecnt = 0  
         IF @n_palletcnt = NULL SELECT @n_palletcnt = 0  
  
  
         UPDATE MBOL WITH (ROWLOCK)  
         SET [CustCnt]    = CustCnt + @n_custcnt,  
             [Weight]     = MBOL.Weight + @n_weight,  
             [Cube]       = MBOL.Cube + @n_cube,  
             [PalletCnt]  = PalletCnt + @n_palletcnt,  
             [CaseCnt]    = CaseCnt + @n_casecnt,  
             [VoyageNumber] = CASE WHEN VoyageNumber IS NULL OR VoyageNumber = '' THEN  
                                   @c_VoyageNumber  
                              ELSE  
                                  MBOL.VoyageNumber  
                              END,  
             EditDate = GETDATE(), -- KHLim01  
             [TrafficCop] = NULL  
         WHERE MBOL.MBOLKey = @c_MBOLKey  
  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0 OR @n_cnt = 0  
         BEGIN  
            SELECT @n_Continue = 3  
            SELECT @n_err=72601  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table MBOL. (ntrMBOLDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         END  
  
         FETCH NEXT FROM C_trMBOLDetail INTO @c_MBOLKey, @n_weight, @n_cube, @n_custcnt  
      END -- While  
      CLOSE C_trMBOLDetail  
      DEALLOCATE C_trMBOLDetail  
   END  
  
   /**** To Calculate Weight, Cube, Pallet, Case and Customer Cnt ****/  
  
   --SOS#168916  NJOW01  
   IF (@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN  
        IF EXISTS(SELECT 1  
                FROM   INSERTED I  
                JOIN   Orders O WITH (NOLOCK) ON (O.OrderKey = I.OrderKey)  
                JOIN   StorerConfig S WITH (NOLOCK) ON (S.StorerKey = O.StorerKey)  
                WHERE  S.sValue NOT IN ('0','')  
                AND    S.Configkey = 'MBOLDEFAULT')  
      BEGIN  
          UPDATE MBOL WITH (ROWLOCK)  
          SET NoOfIdsCarton = CASE WHEN MBOL.userdefine09 = 'IDS' THEN  
                                   (SELECT SUM(MD.totalcartons) FROM MBOLDETAIL MD (NOLOCK) WHERE MD.MBOLKey = MBOL.MBOLKey)  
                              ELSE 0 END,  
               NoOfCustomerCarton = CASE WHEN MBOL.userdefine09 = 'CUSTOMER' THEN  
                                        (SELECT SUM(MD.totalcartons) FROM MBOLDETAIL MD (NOLOCK) WHERE MD.MBOLKey = MBOL.MBOLKey)  
                                    ELSE 0 END,  
               EditDate = GETDATE(), -- KHLim01  
               TrafficCop = NULL  
           FROM MBOL  
           WHERE MBOL.MBOLKey IN (SELECT DISTINCT MBOLKey FROM INSERTED)  
          SELECT @n_err = @@ERROR  
          IF @n_err <> 0  
          BEGIN  
             SELECT @n_Continue = 3  
             SELECT @n_err=72621  
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table MBOL. (ntrMBOLDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
          END  
      END  
   END  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM storerconfig s (NOLOCK)  
                 JOIN orders o (NOLOCK) on s.storerkey = o.storerkey  
                 JOIN INSERTED i (NOLOCK) on i.orderkey = o.orderkey  
                 WHERE s.configkey = 'WTS-ITF'  
                   AND s.svalue = '1')  
      BEGIN  
         UPDATE md  
            SET md.TrafficCop = NULL,  
                md.UserDefine01 = l.UserDefine10  
               ,md.EditDate = GETDATE() -- KHLim01  
         FROM MBOLDetail md  
         JOIN INSERTED i on md.MBOLKey = i.MBOLKey and md.LoadKey = i.LoadKey  
         JOIN LoadPlan l (NOLOCK) on i.LoadKey = l.LoadKey  
      END  
   END  
   -- end: populate UserDefine01  
  
   IF @n_Continue = 1 or @n_Continue = 2  
   BEGIN  
      DECLARE @cTrafficCop NVARCHAR(1)  
  
      DECLARE @tPack TABLE  
         (PickSlipNo NVARCHAR(10),  
          LabelNo    NVARCHAR(20),  
          CartonNo   INT,  
          [WEIGHT]   REAL,  
          [CUBE]     REAL)  
  
  
      DECLARE CUR_DELMBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT MBOLKey, ISNULL(TrafficCop,'')  
      FROM INSERTED  
  
      OPEN CUR_DELMBOL  
      FETCH NEXT FROM CUR_DELMBOL INTO @c_MBOLKey, @cTrafficCop  
  
      WHILE @@FETCH_STATUS <>  -1  
      BEGIN  
         IF ISNULL(@cTrafficCop,'') = '1'  
            GOTO FETCH_NEXT  
  
         IF EXISTS(SELECT 1 FROM ORDERDETAIL o WITH (NOLOCK) WHERE o.MBOLKey = @c_MBOLKey  
                   AND o.ConsoOrderKey IS NOT NULL AND o.ConsoOrderKey <> '')  
         BEGIN  
  
            INSERT INTO @tPack (PickSlipNo, LabelNo, CartonNo, [WEIGHT], [CUBE])  
            SELECT DISTINCT P.PickSlipNo, PD.LabelNo, PD.CartonNo,0, 0  
            FROM   PICKDETAIL p WITH (NOLOCK)  
            JOIN   PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = P.PickSlipNo  
                                    AND PD.DropID = P.DropID  
            JOIN  MBOLDETAIL MD WITH (NOLOCK) ON MD.OrderKey = P.OrderKey  
            WHERE MD.MBOLKey = @c_MBOLKey  
  
            UPDATE TP  
               SET [WEIGHT]  = pi1.[Weight],  
                   TP.[CUBE] = CASE WHEN pi1.[CUBE] < 1.00 THEN 1.00 ELSE pi1.[CUBE] END  
            FROM @tPack TP  
            JOIN PackInfo pi1 WITH (NOLOCK) ON pi1.PickSlipNo = TP.PickSlipNo AND pi1.CartonNo = TP.CartonNo  
  
            IF EXISTS(SELECT 1 FROM @tPack WHERE [WEIGHT]=0)  
            BEGIN  
               UPDATE TP  
         SET TP.[WEIGHT]  = TWeight.[WEIGHT],  
                      TP.[CUBE] = CASE WHEN TP.[CUBE] < 1.00 THEN 1.00 ELSE TP.[CUBE] END  
               FROM @tPack TP  
               JOIN (SELECT PD.PickSlipNo, PD.CartonNo, SUM(S.STDGROSSWGT * PD.Qty) AS [WEIGHT]  
                     FROM PACKDETAIL PD WITH (NOLOCK)  
                     JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU  
                     JOIN @tPack TP2 ON TP2.PickSlipNo = PD.PickSlipNo AND TP2.CartonNo = PD.CartonNo  
                     GROUP BY PD.PickSlipNo, PD.CartonNo) AS TWeight ON TP.PickSlipNo = TWeight.PickSlipNo  
                              AND TP.CartonNo = TWeight.CartonNo  
               WHERE TP.[WEIGHT] = 0  
  
            END  
  
            UPDATE MBOL  
               SET [Weight]  =  PK.WEIGHT,  
                   MBOL.[Cube] = PK.Cube,  
                   MBOL.CaseCnt = PK.CaseCnt,  
                   EditDate = GETDATE(), -- KH01  
                   TrafficCop=NULL  
            FROM MBOL  
            JOIN (SELECT @c_MBOLKey AS MBOLKey, SUM(WEIGHT) AS Weight, SUM(CUBE) AS Cube, COUNT(*) AS CaseCnt  
                  FROM @tPack) AS PK ON MBOL.MBOLKey = PK.MBOLKey  
  
         END  
  
FETCH_NEXT:  
         DELETE FROM @tPack  
  
         FETCH NEXT FROM CUR_DELMBOL INTO @c_MBOLKey, @cTrafficCop  
      END -- While CUR_DELMBOL  
      CLOSE CUR_DELMBOL  
      DEALLOCATE CUR_DELMBOL  
  
   END  
  
QUIT:  
  
IF @n_Continue=3  -- Error Occured - Process And Return  
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrMBOLDetailAdd'  
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
END  

GO