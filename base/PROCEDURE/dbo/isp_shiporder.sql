SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_ShipOrder                                       */  
/* Creation Date:                                                        */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.2                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author    Ver.  Purposes                                 */  
/* 20-Sept-2005 Shong     1.0   Take out the Table Variable, HK having   */  
/*                              pblm deploy into thier SQL 7 database.   */  
/*                              Convert Select MIN into Cursor Loop      */  
/* 11-Oct-2005  Shong     1.0   Fix for Orders that have ZERO allocated  */  
/*                              qty will not fire the                    */  
/*                              ntrOrderHeaderUpdate                     */  
/* 20-Mar-2009  YokeBeen  1.1   Added Trigger Point for CMS Project.     */  
/*                              - SOS#170509 - (YokeBeen01)              */  
/* 11-Mar-2010  YokeBeen  1.2   Modified StorerConfig.ConfigKey="MBOLLOG"*/  
/*                              as Generic trigger point - (YokeBeen02)  */  
/* 24-May-2012  TLTING01  1.3   Performance Tune                         */  
/* 21-Sep-2016  SHONG     1.4   Performance Tuning                       */  
/* 21-Sep-2018  SHONG     1.5   filter shipflag <> Y                     */  
/* 28-Jan-2019  TLTING_ext 1.6  enlarge externorderkey field length      */
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_ShipOrder]  
   @c_MBOLKey       NVARCHAR(10),  
   @c_OrderKey      NVARCHAR(10),  
   @c_RealTmShip    NVARCHAR(1),  
   @b_Success       int = 1        OUTPUT,  
   @n_err           int = 0        OUTPUT,  
   @c_errmsg        NVARCHAR(255) = '' OUTPUT  
AS  
BEGIN -- main  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_debug int  
   SELECT @b_debug = 0  
  
   DECLARE   @n_continue           int  
   ,         @n_starttcnt          int       -- Holds the current transaction count  
   ,         @c_preprocess         NVARCHAR(250) -- preprocess  
   ,         @c_pstprocess         NVARCHAR(250) -- post process  
   ,         @n_cnt                int  
   ,         @c_facility           NVARCHAR(5)  
   ,         @c_OWITF              NVARCHAR(1)  
   ,         @c_authority          NVARCHAR(1)  
   ,         @c_OrderKeyShip       NVARCHAR(10)  
   ,         @c_asn                NVARCHAR(1)   -- Added By Vicky  
   ,         @c_ulpitf             NVARCHAR(1)   -- Added By Vicky  
   ,         @c_externorderkey     NVARCHAR(50)  --tlting_ext   -- Added By Vicky
   ,         @c_lastload           NVARCHAR(1)   -- Added By Vicky  
   ,         @c_short              NVARCHAR (10)  
   ,         @c_trmlogkey          NVARCHAR(10)  
   ,         @c_NIKEREGITF         NVARCHAR(1)   -- Added by YokeBeen (SOS#15350/15353)  
   ,         @c_LoadKey            NVARCHAR(10)  
   ,         @c_OrdIssued          NVARCHAR(1)  
   ,         @c_LongConfig      NVARCHAR(250)  
   ,         @c_NZShort            NVARCHAR (10)   -- Added by Maryvong (NZMM - FBR18999 Shipment Confirmation Export)  
   ,         @c_CurSOStatus        NVARCHAR (10)  
  
  
   DECLARE @c_Status  NVARCHAR(1),  
           @n_StatusCnt int  
  
   SELECT @n_continue=1  
  
   DECLARE @c_PickDetailKey     NVARCHAR(10),  
           @c_PickDetailKeyship NVARCHAR(10)  
  
  
   -- Create Temp Table for Updating  
   CREATE TABLE #OrderRef (  
   rowref INT NOT NULL IDENTITY(1,1) PRIMARY KEY ,  
    MBOLKEY         NVARCHAR(10),  
    LoadKey         NVARCHAR(10),  
    OrderKey        NVARCHAR(10),  
    OrderLineNumber NVARCHAR(5) )  
      
      
   INSERT INTO #OrderRef (MBOLKEY, LoadKey, OrderKey, OrderLineNumber)      
   SELECT ORDERDETAIL.MBOLKEY, ORDERDETAIL.LoadKey, ORDERDETAIL.OrderKey, ORDERDETAIL.OrderLineNumber    
   FROM   MBOLDETAIL WITH (NOLOCK)    
   JOIN   ORDERDETAIL WITH (NOLOCK)ON ( MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey )  
   WHERE MBOLDETAIL.MBOLKey  = @c_MBOLKey  
   AND   MBOLDETAIL.OrderKey = @c_OrderKey   
  
  -- Create index OrderRef_ordline on #OrderRef (OrderKey, OrderLineNumber   )  
  
   -- 20th Sep 2005 Convert Table Variable into Cursor Loop  
   -- HK still running SQL version 7  
   -- DECLARE @PickDetailKey_Table Table (PickDetailKey NVARCHAR(10))  
  
   DECLARE C_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PickDetailKey  
   FROM   PICKDETAIL (NOLOCK)  
   JOIN  #OrderRef (NOLOCK) ON (#OrderRef.OrderKey = PICKDETAIL.OrderKey AND  
                                #OrderRef.OrderLineNumber = PICKDETAIL.OrderLineNumber)  
   WHERE [Status] < '9'   
   AND   ShipFlag <> 'Y'  
   ORDER BY PickDetailKey  
  
  
   OPEN C_PickDetailKey  
  
   -- Clean all the tran_count  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   DECLARE @c_PickOrderKey    NVARCHAR(10),  
            @c_XmitLogKey     NVARCHAR(10),  
            @c_PickOrderLine  NVARCHAR(5),  
            @c_StorerKey      NVARCHAR(20),  
            @c_OrderType      NVARCHAR(10),  
            @c_OrdRoute       NVARCHAR(10)  
  
  
   IF @n_continue = 1 or @n_continue=2  
   BEGIN -- 01  
      -- Added By SHONG on 30-Mar-2005  
      -- Update by PickDetail Level  
      -- To reduce blocking  
      DECLARE @cPickDetailKey NVARCHAR(10)  
  
      SELECT @cPickDetailKey = ''  
  
      WHILE 1=1  
      BEGIN  
         -- 20th Sep 2005 By SHONG  
--          SELECT @cPickDetailKey = MIN(PickDetailKey)  
--          FROM   @PickDetailKey_Table  
--          WHERE  PickDetailKey > @cPickDetailKey  
         FETCH NEXT FROM C_PickDetailKey INTO @cPickDetailKey  
  
         IF dbo.fnc_RTrim(@cPickDetailKey) IS NULL OR dbo.fnc_RTrim(@cPickDetailKey) = '' OR @@FETCH_STATUS = -1  
            BREAK  
  
         IF @c_realtmship = '1'  
         BEGIN  
            BEGIN TRAN  
  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET Status = '9'  
            WHERE PICKDETAILKey = @cPickDetailKey  
            AND   PICKDETAIL.Status < '9'  
  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806     
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_ShipOrder)'   
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '  
               ROLLBACK TRAN  
               GOTO QUIT_SP  
            END  
            ELSE  
            BEGIN  
               WHILE @@TRANCOUNT > 0  
               BEGIN  
                  COMMIT TRAN  
               END  
            END  
         END -- IF @c_realtmship = '1'  
         ELSE  
         BEGIN  
            BEGIN TRAN  
  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET ShipFlag = 'Y',  
                Trafficcop = NULL,  
                EditDate = GETDATE(),  
                EditWho  = SUSER_SNAME()  
            WHERE PICKDETAILKey = @cPickDetailKey  
            AND   PICKDETAIL.Status < '9'   
            AND   ShipFlag <> 'Y'  
  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806    
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_ShipOrder)' + ' ( '   
                                       + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '  
               ROLLBACK TRAN  
               GOTO QUIT_SP  
            END  
            ELSE  
            BEGIN  
               WHILE @@TRANCOUNT > 0  
               BEGIN  
                  COMMIT TRAN  
               END  
            END  
         END  
      END -- While  
      -- 20th Sep 2005 By  
      CLOSE C_PickDetailKey  
      DEALLOCATE C_PickDetailKey  
   END -- @n_continue = 1 or @n_continue = 2  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      IF EXISTS(SELECT OrderKey FROM ORDERDETAIL (NOLOCK)  
                  WHERE ORDERDETAIL.OrderKey = @c_OrderKey  
                  AND   ORDERDETAIL.MBOLKey = @c_MBOLKey  
                  AND ORDERDETAIL.Status < '9')  
      BEGIN  
         BEGIN TRAN  
  
         UPDATE ORDERDETAIL WITH (ROWLOCK)  
         SET Status = '9',  
         EditDate = GETDATE(),  
         EditWho  = SUSER_SNAME(),  
         TrafficCop = NULL  
         WHERE ORDERDETAIL.OrderKey = @c_OrderKey  
         AND   ORDERDETAIL.MBOLKey = @c_MBOLKey  
         AND   ORDERDETAIL.Status < '9'  
  
         SELECT @n_err = @@ERROR  
         SELECT @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERS. (isp_ShipOrder)'   
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '  
            ROLLBACK TRAN  
            GOTO QUIT_SP  
         END  
         ELSE  
         BEGIN  
            WHILE @@TRANCOUNT > 0  
            BEGIN  
               COMMIT TRAN  
            END  
         END  
      END -- Exists  
   END -- @n_continue = 1 or @n_continue = 2  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      DECLARE @xStatus   NVARCHAR(10),  
              @xSOStatus NVARCHAR(10)  
  
      SELECT @xStatus = '', @xSOStatus = ''  
  
      SELECT @xStatus   = ORDERS.Status,  
             @xSOStatus = ORDERS.SOSTATUS  
      FROM ORDERS (NOLOCK)  
      WHERE ORDERS.OrderKey = @c_OrderKey  
  
      IF (@xStatus < '9' OR @xSOStatus < '9')  
      BEGIN  
         BEGIN TRAN  
  
         UPDATE ORDERS WITH (ROWLOCK)  
         SET Status = '9',  
         SOStatus = '9',  
         EditDate = GETDATE(),  
         EditWho  = SUSER_SNAME()  
         WHERE ORDERS.OrderKey = @c_OrderKey  
         AND (ORDERS.Status < '9' OR ORDERS.SOSTATUS < '9')  
  
         SELECT @n_err = @@ERROR  
         SELECT @n_cnt = @@ROWCOUNT  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERS. (isp_ShipOrder)'   
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '  
            ROLLBACK TRAN  
            GOTO QUIT_SP  
         END  
         ELSE  
         BEGIN  
            WHILE @@TRANCOUNT > 0  
            BEGIN  
               COMMIT TRAN  
            END  
         END  
      END  
   END -- @n_continue = 1 or @n_continue = 2  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      IF EXISTS(SELECT 1 FROM LOADPLANDETAIL (nolock)  
               WHERE LOADPLANDETAIL.Orderkey = @c_OrderKey  
               AND   LOADPLANDETAIL.Status < '9')  
      BEGIN  
         BEGIN TRAN  
  
         UPDATE LOADPLANDETAIL WITH (ROWLOCK)  
         SET STATUS = '9',  
         EditDate = GETDATE(),  
         EditWho  = SUSER_SNAME(),  
         Trafficcop = null  
         FROM LOADPLANDETAIL  
         JOIN #OrderRef (NOLOCK) ON (LOADPLANDETAIL.Loadkey  = #OrderRef.Loadkey AND  
                                     LOADPLANDETAIL.Orderkey = #OrderRef.Orderkey )  
         AND   LOADPLANDETAIL.Status < '9'  
         -- End - SOS20494  
  
         SELECT @n_err = @@ERROR  
         SELECT @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (isp_ShipOrder)'   
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '  
            ROLLBACK TRAN  
            GOTO QUIT_SP  
         END  
         ELSE  
         BEGIN  
            WHILE @@TRANCOUNT > 0  
            BEGIN  
               COMMIT TRAN  
            END  
         END  
      END  
   END -- @n_continue = 1 or @n_continue = 2  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @c_LoadKey = ''  
  
      DECLARE C_OrderRef_LoadKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LoadKey  
         FROM  #OrderRef (NOLOCK)  
         ORDER BY LoadKey  
  
      OPEN C_OrderRef_LoadKey  
  
      WHILE 1=1  
      BEGIN  
         -- 20th Sep 2005 By SHONG  
         -- SELECT @c_LoadKey = MIN(LoadKey)  
         -- FROM  #OrderRef (NOLOCK)  
         -- WHERE LoadKey > @c_LoadKey  
         FETCH NEXT FROM C_OrderRef_LoadKey INTO @c_LoadKey  
  
         IF dbo.fnc_RTrim(@c_LoadKey) IS NULL OR dbo.fnc_RTrim(@c_LoadKey) = '' OR @@FETCH_STATUS = -1  
            BREAK  
  
         SELECT @c_Status = Status,  
                @n_StatusCnt = COUNT(DISTINCT Status)  
         FROM   LoadplanDetail (NOLOCK)  
         WHERE  LoadKey = @c_LoadKey  
         GROUP BY status  
  
         IF @@ROWCOUNT = 1 AND @c_Status = '9' AND @n_StatusCnt = 1  
         BEGIN  
            BEGIN TRAN  
  
            UPDATE LoadPlan WITH (ROWLOCK)  
            SET Status = '9',  
            EditDate = GETDATE(),  
            EditWho  = SUSER_SNAME()  
            -- TrafficCop = NULL  -- (YokeBeen01)  
            WHERE LoadKey = @c_LoadKey  
            AND   Status < '9'  
  
            SELECT @n_err = @@ERROR  
            SELECT @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806     
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (isp_ShipOrder)'   
                                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '  
               ROLLBACK TRAN  
               GOTO QUIT_SP  
            END  
            ELSE  
            BEGIN  
               WHILE @@TRANCOUNT > 0  
               BEGIN  
                  COMMIT TRAN  
               END  
            END  
         END  
      END -- WHILE loadkey  
      CLOSE C_OrderRef_LoadKey  
      DEALLOCATE C_OrderRef_LoadKey  
   END  
  
   -- Generate Interface File Here................  
   SELECT @n_starttcnt=@@TRANCOUNT  
   BEGIN TRAN  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      DECLARE @c_ConfigKey NVARCHAR(30)  
  
      SELECT @c_StorerKey = StorerKey,  
             @c_Status    = Status,  
             @c_OrderType = Type,  
             @c_CurSOStatus = SOStatus  
      FROM   ORDERS (NOLOCK)  
      WHERE  OrderKey = @c_OrderKey  
  
      IF @c_Status = '9' OR @c_CurSOStatus = '9'  
      BEGIN  
         SELECT @c_ConfigKey = SPACE(30)  
         -- tlting01  
         CREATE TABLE #StorerCfg  
         (  Rowref INT NOT NULL IDENTITY(1,1) Primary KEY,  
            StorerKey  NVARCHAR(15),  
            ConfigKey  NVARCHAR(30) )  
  
         INSERT INTO #StorerCfg (StorerKey, ConfigKey)  
         SELECT StorerKey, ConfigKey  
         FROM   StorerConfig with (NOLOCK)  
         WHERE  Storerkey = @c_StorerKey  
         AND    sValue = '1'  
  
       --  CREATE INDEX IX_StorerCfg_01 on #StorerCfg (ConfigKey)  -- TLTING01  
  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'NON-OW-ITS')  
         BEGIN  
         -- Added BY SHONG  
         -- For IDSHK TBL Implimentation  
         -- Date: 12-May-2003  
  
            EXEC ispGenTransmitLog 'NON-OW-ITS', @c_OrderKey, '', @c_StorerKey, ''  
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
  
         END  
  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'ILSITF')  
         BEGIN  
            EXEC ispGenTransmitLog 'ORDERS', @c_OrderKey, '', '', ''  
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
         END  
  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'MBOLSHIPITF')  
         BEGIN  
            SELECT @c_LoadKey = SubString(@c_Loadkey,1,5)  
  
            EXEC ispGenTransmitLog 'ORDERS', @c_MBOLKey, @c_LoadKey, @c_OrderKey, @c_StorerKey  
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
         END  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'MBOLLOG')  
         BEGIN  
            EXEC ispGenTransmitLog3 'MBOLLOG', @c_MBOLKey, '', @c_StorerKey, ''  -- (YokeBeen02)  
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
         END  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'TBLHKITF')  
         BEGIN  
            IF EXISTS (SELECT 1  FROM ROUTEMASTER (NOLOCK)  
                        WHERE ROUTEMASTER.Route = @c_OrdRoute  
                        AND   ROUTEMASTER.ZipCodeTo = 'EXP')  
            BEGIN  
               EXEC ispGenTransmitLog2 'TBLASNTODC', @c_OrderKey, '', '', ''  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
            END -- route  
  
            IF @c_OrderType <> 'M'  
            BEGIN  
               EXEC ispGenTransmitLog2 'TBLHKSHP', @c_OrderKey, '', @c_StorerKey, ''  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
            END -- Order type <> M  
  
            IF @c_OrderType = 'R'  
            BEGIN  
               EXEC ispGenTransmitLog2 'TBLREPTKT', @c_OrderKey, '', @c_StorerKey, ''  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
            END -- Order type = 'R'  
         END  --   @c_ConfigKey = 'TBLHKITF'  
  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'NIKEHKITF')  
         BEGIN  
            EXEC ispGenTransmitLog 'NIKESHIP', @c_OrderKey, '', @c_StorerKey, ''  
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
         END  
  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'FUJIMYITF')  
         BEGIN  
            -- Changed by June 30.Mar.2004  
            -- IF @c_ExternOrderKey Like 'I%' AND  
            IF @c_ExternOrderKey NOT Like 'I%' AND  
            ( dbo.fnc_RTrim(@c_OrdIssued) IS NULL OR dbo.fnc_RTrim(@c_OrdIssued) = '' )  
            BEGIN  
               EXEC ispGenTransmitLog 'FUJIMYORD', @c_OrderKey, '', @c_StorerKey, ''  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
            END  
         END -- @c_ConfigKey = 'FUJIMYITF'  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                     AND configkey = 'NIKEREGITF')  
         BEGIN  
            IF @c_OrderType <> 'M'  
            BEGIN  
               -- Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)  
               -- Changed to trigger records into NSCLog table with 'NSCKEY'.  
               EXEC ispGenNSCLog 'NIKEREGORD', @c_OrderKey, '', @c_StorerKey, ''  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
               -- End Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project (SOS#20000)  
            END -- Order type <> M  
         END  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'CNNIKEITF')  
         BEGIN  
            IF @c_OrderType <> 'TR'  
            BEGIN  
               IF @c_OrderType = 'TF'  
               BEGIN  
                  EXEC ispGenTransmitLog 'TFO', @c_OrderKey, '', @c_StorerKey, ''  
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
               END  
               ELSE IF @c_OrderType NOT IN ('TF', 'DES')  
               BEGIN  
                  EXEC ispGenTransmitLog 'NIKESHIP', @c_OrderKey, '', @c_StorerKey, ''  
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
               END  
            END  
         END  
  
        IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'NZMMITF')  
            -- Added by MaryVong on 09-Mar-2004 (NZMM FBR18999 Shipment Confirmation Export) -Start  
         BEGIN  
            -- When short='SHIP', insert a record into TransmitLog2 table  
            SELECT @c_NZShort = Short  
            FROM CODELKUP (NOLOCK)  
            WHERE ListName = 'NZMMSOCFM'  
            AND Code = @c_OrderType  
  
            IF @c_NZShort = 'SHIP'  
            BEGIN  
               EXEC ispGenTransmitLog2 'NZSHIPCONF', @c_OrderKey, '', @c_StorerKey, ''  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
               IF @b_success <> 1  
               BEGIN  
                  SELECT @n_continue = 3  
               END  
            END -- @c_NZShort = 'SHIP'  
         END -- @c_ConfigKey = 'NZMMITF'  
  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'NWInterface')  
            -- Added by MaryVong on 09-Mar-2004 (NZMM FBR18999 Shipment Confirmation Export) -End  
            -- Added by MaryVong on 26-May-2004 (IDSHK - Watson Shipment Confirmation Export) -Start  
         BEGIN  
  
            IF ( select Convert(char(10),codelkup.notes) from codelkup (nolock), orders (nolock)  
                  where Codelkup.code = Orders.type  
                  and Orders.Orderkey = @c_OrderKey  
                  and Codelkup.listname = 'ORDERTYPE'  
                  and Codelkup.long = @c_StorerKey ) = 'RTV'  
            BEGIN  
               -- SOS27626  
               -- EXEC ispGenTransmitLog2 'NWSHPRTV', @c_OrderKey, '', @c_StorerKey, ''  
               EXEC ispGenTransmitLog3 'NWSHPRTV', @c_OrderKey, '', @c_StorerKey, ''  
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
            END  
            ELSE  
            BEGIN  
               -- SOS27626  
               -- EXEC ispGenTransmitLog2 'NWSHPTRF', @c_OrderKey, '', @c_StorerKey, ''  
               EXEC ispGenTransmitLog3 'NWSHPTRF', @c_OrderKey, '', @c_StorerKey, ''  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
            END  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
            END  
         END --  'NWInterface'  
            -- Added by MaryVong on 26-May-2004 (IDSHK - Watson Shipment Confirmation Export) -End  
  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'WTCInterface')  
            -- Added by MaryVong on 23-Jun-2004 (IDSHK-WTC Shipment Confirmation Export) -Start  
         BEGIN  
            EXEC ispGenTransmitLog2 'WTCSHPCF', @c_OrderKey, '', @c_StorerKey, ''  
                  , @b_success OUTPUT  
                  , @n_err OUTPUT  
                  , @c_errmsg OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
            END  
         END  
  
         IF EXISTS(SELECT 1 FROM #StorerCfg (NOLOCK) WHERE storerkey = @c_StorerKey  
                      AND configkey = 'SOCFMLOG')  
            -- Added by SHONG ON 10-Oct-2006  
            -- Generic Ship Confirm Interface  
         BEGIN  
            EXEC dbo.ispGenTransmitLog3 'SOCFMLOG', @c_OrderKey, @c_OrderType, @c_StorerKey, ''  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
            End  
         END  
      END -- IF @c_Status = '9'  
   END -- n_continue = 1, Generate Interface  
  
   -- Added by MaryVong on 23-Jun-2004 (IDSHK-WTC Shipment Confirmation Export) -End  
  
   /* #INCLUDE <TRMBOHU2.SQL> */  
  
  
QUIT_SP:  
  
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_ShipOrder'  
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
END -- procedure  

GO