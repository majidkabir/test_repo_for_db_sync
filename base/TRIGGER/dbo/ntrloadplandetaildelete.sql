SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ntrLoadPlanDetailDelete                                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 02-Mar-2006  Shong     1.0   Set OrderDetail.Loadkey to NULL instead */
/*                              of Blank.                               */
/* 27-Aug-2008  RickyYee  1.0   Update RDSORders.Loadkey when Orders    */
/*                              remove from the LoadplanDetail          */
/*                              (RY_082708)                             */
/* 22-Sep-2008  Shong     1.1   Reverse Loadplan Status When all Lines  */
/*                              Deleted                                 */
/* 11-Mar-2009  YokeBeen  1.2   Added Trigger Point for CMS Project.    */
/*                              - SOS#170510 - (YokeBeen01)             */
/* 19-Mar-2010  Shong     1.3   Delete PickHeader When Loadplan Detail  */
/*                              Deleted.                                */
/*  9-Jun-2011  KHLim01   1.4   Insert Delete log                       */
/* 14-Jul-2011  KHLim02   1.5   GetRight for Delete log                 */
/* 04-May-2016  tlting    1.6   performance tune - DoNotCalcLPAllocInfo */
/* 18-Jul-2016  SHONG01   1.7   Update LoadKey to Pick & Pack Tables    */
/*                              SOS#373412                              */
/* 20-Sep-2016  TLTING    1.7   Change SetROWCOUNT 1 to Top 1           */
/* 20-Oct-2016  SHONG     1.8   Update Loadplan Status                  */
/* 16-May-2017  NJOW01    1.9   WMS-1798 Allow config to call custom sp */
/* 28-Sep-2018  TLTING    1.10  remove row lock                         */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrLoadPlanDetailDelete]
ON [dbo].[LoadPlanDetail]
FOR DELETE
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

   DECLARE @b_Success       int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err           int       -- Error number returned by stored procedure or this trigger
         , @c_errmsg        NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         , @n_continue      int       -- continuation flag: 1=Continue, 2=failed but continue processsing, 
                                      -- 3=failed do not continue processing, 4=successful but skip further processing
         , @n_starttcnt     int       -- Holds the current transaction count
         , @n_cnt           int       -- Holds the number of rows affected by the DELETE statement that fired this trigger.
         , @c_authority     NVARCHAR(1)
         , @c_storerkey     NVARCHAR(10)
         , @c_LPCANCCMS     NVARCHAR(1)   -- (YokeBeen01) 

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   /* #INCLUDE <TRMBODD1.SQL> */

   IF (select count(*) from DELETED) =
      (select count(*) from DELETED where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   -- SOS32395 : Move from BATCHPICK
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
      FROM   DELETED 
      JOIN   ORDERS WITH (NOLOCK) ON (DELETED.Orderkey = ORDERS.Orderkey) 
   END

   -- Added for IDSV5 by June 26.Jun.02, (extract from IDSHK) *** Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      Execute nspGetRight null,  -- facility
               @c_storerkey,  -- Storerkey : SOS32395
               null,          -- Sku
               'FinalizeLP',     -- Configkey
               @b_success     output,
               @c_authority   output,
               @n_err         output,
               @c_errmsg      output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'ntrLoadplanDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE IF @c_authority = '1'
      BEGIN
         -- Once finalized, no more deletion allowed, requested by KO, 5th Jan 2002
         IF EXISTS (SELECT 1 FROM LOADPLAN WITH (NOLOCK)
                      JOIN DELETED ON (LOADPLAN.Loadkey = DELETED.Loadkey) 
                       AND LOADPLAN.FinalizeFlag = 'Y' ) -- AND LOADPLAN.Status IN ('5', '6', '7', '8','9')))
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err=72001
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                             + ': Loadplan has been finalized. DELETE rejected. (ntrLoadPlanDetailDelete)'
         END
      END
   END   -- Added for IDSV5 by June 26.Jun.02, (extract from IDSHK) *** End

   -- Added for IDSV5 by June 26.Jun.02, (extract from IDSHK) *** Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      Execute nspGetRight null,  -- facility
               @c_StorerKey,  -- Storerkey
               null,          -- Sku
               'BATCHPICK',      -- Configkey
               @b_success     output,
               @c_authority   output,
               @n_err         output,
               @c_errmsg      output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'ntrLoadplanDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE IF @c_authority = '1'
      BEGIN
         -- Customized for Batch Pick
         IF EXISTS (SELECT 1 FROM TASKDETAIL WITH (NOLOCK)
                      JOIN DELETED ON (Taskdetail.Sourcekey = DELETED.LOADKEY) 
                      JOIN ORDERS WITH (NOLOCK) ON (DELETED.Orderkey = ORDERS.Orderkey) 
                     WHERE ORDERS.Type NOT IN ('M', 'I')
                       AND ORDERS.UserDefine08 = 'N' -- These orders are allocated in LoadpLan, and thus, batch picked.
                       AND TASKDETAIL.Sourcetype = 'BATCHPICK' )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err=72002
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                   + ': Batch Pick Tasks has been released. Unable to delete Load Detail(ntrLoadPlanDetailDelete)'
         END
         -- batch pick
      END
   END  -- Added for IDSV5 by June 26.Jun.02, (extract from IDSHK) *** End

   --NJOW01
   IF @n_continue=1 or @n_continue=2          
   BEGIN   	  
      IF EXISTS (SELECT 1 FROM DELETED d   ----->Put INSERTED if INSERT action
                 JOIN ORDERS o WITH (NOLOCK) ON d.Orderkey = o.Orderkey
                 JOIN storerconfig s WITH (NOLOCK) ON  o.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'LoadPlanDetailTrigger_SP')   -----> Current table trigger storerconfig
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
   
         EXECUTE dbo.isp_LoadPlanDetailTrigger_Wrapper ----->wrapper for current table trigger
                   'DELETE'  -----> @c_Action can be INSERT, UPDATE, DELETE
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  
   
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrLoadPlanDetailDelete ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END      

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      UPDATE ORDERS  
    SET LoadKey = '',
             Editdate = GETDATE(),
             Trafficcop = NULL
         --      rdd = '' -- use as loadsheetno for MANILA  :SOS 11354 - no need to re-initialize
        FROM ORDERS 
        JOIN DELETED ON (ORDERS.OrderKey = DELETED.OrderKey AND ORDERS.Loadkey = DELETED.Loadkey) 

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72003  
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                          + ': Update Failed On Table ORDERS. (ntrLoadPlanDetailAdd)' 
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      UPDATE ORDERDETAIL  
          -- Change By Shong on 03-Mar-2006, Instead of BLANK, Set it to NULL.
         SET LoadKey = NULL,
             EditDate = GETDATE(),
             Trafficcop = NULL
        FROM ORDERDETAIL 
        JOIN DELETED ON (ORDERDETAIL.OrderKey = DELETED.OrderKey AND ORDERDETAIL.Loadkey = DELETED.Loadkey) 

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72004  
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                          + ': Update Failed On Table ORDERDETAIL. (ntrLoadPlanDetailAdd)'
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

	-- Added By Ricky on 28th Aug 2008 Begin (RY_082708)
	-- Update RDSORDERS When Delete from Load Plan Detail
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
      UPDATE rdsORDERS  
         SET LoadKey = '',
             TrafficCop = NULL
        FROM rdsORDERS 
        JOIN DELETED ON (rdsORDERS.OrderKey = DELETED.OrderKey) 

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72005   
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                          + ': Update Failed On Table rdsORDERS. (ntrLoadPlanDetaildelete)' 
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
	END 
	-- Added By Ricky on 28th Aug 2008 End (RY_082708)
	
   -- SOS 7261
   -- wally 19.aug.2002
   -- delete the record from orderscan table
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DELETE ORDERSCAN
      FROM ORDERSCAN O 
      JOIN DELETED D ON O.LOADKEY = D.LOADKEY AND O.ORDERKEY = D.ORDERKEY

      SELECT @n_err = @@error, @n_cnt = @@rowcount

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72006   
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                          + ': Delete Failed On Table ORDERSCAN. (ntrLoadPlanDetailAdd)' 
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @n_casecnt int,
              @n_palletcnt int,
              @n_weight decimal(15, 4),
              @n_cube decimal(15, 4),
              @n_custcnt int,
              @n_ordercnt int,
              @c_DeleteLoadKey NVARCHAR(10)
      DECLARE @cDoNotCalcLPAllocInfo VARCHAR(10)  

      DECLARE @c_LP_Min_Status NVARCHAR(10),
	           @c_LP_Max_Status NVARCHAR(10), 
	           @c_LP_Cur_Status NVARCHAR(10) , 
	           @c_LP_New_Status NVARCHAR(10)  
  
      SET @n_casecnt = 0
      SET @n_palletcnt = 0
      SET @n_weight = 0
      SET @n_cube = 0
      SET @n_custcnt = 0
      SET @n_ordercnt = 0
      SET @c_DeleteLoadKey = ''
              
      SET @cDoNotCalcLPAllocInfo = ''  

      SELECT @cDoNotCalcLPAllocInfo = ISNULL(sValue, '0')   
      FROM  STORERCONFIG WITH (NOLOCK)   
      WHERE StorerKey = @c_StorerKey   
      AND   ConfigKey = 'DoNotCalcLPAllocInfo'   
      AND   sVAlue = '1' 
        
      DECLARE CUR_DELETED_LOADKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LoadKey FROM DELETED
   
      OPEN CUR_DELETED_LOADKEY
   
      FETCH NEXT FROM CUR_DELETED_LOADKEY INTO @c_DeleteLoadKey 
   
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2) 
      BEGIN 
         IF NOT EXISTS (SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @c_DeleteLoadKey)
         BEGIN
            UPDATE LoadPlan  
               SET CustCnt   = 0,
                     OrderCnt  = 0,
                     Weight    = 0,
                     Cube      = 0,
                     PalletCnt = 0,
                     CaseCnt   = 0, 
                     Status    = '0', 
                     editdate  = getdate(),
                     TrafficCop = NULL 
               WHERE LoadPlan.LoadKey = @c_DeleteLoadKey 
               AND Status <= '5'
               AND FinalizeFlag = 'N'
   
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72007  
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                                 + ': Update Failed On Table LoadPlan. (ntrLoadPlanDetailAdd)' 
                                 + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
   
            -- (YokeBeen01) - Start 
            -- Trigger record into CMSLOG with normal Status upon the last LoadplanDetail line is to be purged.
            -- This record will be updated from CMSLOG.TransmitFlag from "0" to "2" in the Loadplan Header Trigger, 
            -- when the Loadplan Header record is to be purged.
            IF @n_continue = 1 or @n_continue = 2  
            BEGIN  
               SELECT @c_LPCANCCMS = 0
               SELECT @b_success = 0
   
               EXECUTE nspGetRight
                        NULL,          -- Facility
                        @c_StorerKey,  -- Storerkey
                        NULL,          -- Sku
                        'LPCANCCMS',   -- Configkey
                        @b_success    output,
                        @c_LPCANCCMS  output,
                        @n_err        output,
                        @c_errmsg     output
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrLoadPlandELETE' + dbo.fnc_RTrim(@c_errmsg)
               END
   
               IF @b_success = 1 AND @c_LPCANCCMS = '1'
               BEGIN
                  EXEC ispGenCMSLog 'LPCANCCMS', @c_DeleteLoadKey, 'L', @c_StorerKey, ''
                                    , @b_success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT
   
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72008   
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                           + ': Unable to Generate CMSLog Record, TableName = LPCANCCMS (ntrLoadPlanDetailDelete)' 
                           + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- IF @b_success = 1 AND @c_LPCANCCMS = '1'
            END -- IF @n_continue = 1 or @n_continue = 2  
         -- (YokeBeen01) - End 
         END -- No More Loadplan Detail 
         ELSE
         BEGIN 
         	IF @cDoNotCalcLPAllocInfo <> '1' 
            BEGIN
               SELECT @n_palletcnt = CONVERT(Integer, SUM(CASE WHEN PACK.Pallet = 0 THEN 0
                                                            ELSE (ORDERDETAIL.OpenQty / PACK.Pallet) END)),
                      @n_casecnt = CONVERT(Integer, SUM(CASE WHEN PACK.CaseCnt = 0 THEN 0
                                                         ELSE (ORDERDETAIL.OpenQty / PACK.CaseCnt) END))
               FROM ORDERDETAIL WITH (NOLOCK)
               JOIN LoadPlanDetail WITH (NOLOCK) ON ORDERDETAIL.OrderKey = LoadPlanDetail.OrderKey 
               JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.SKU = SKU.SKU AND ORDERDETAIL.Storerkey = SKU.Storerkey
               JOIN PACK WITH (NOLOCK) ON ORDERDETAIL.Packkey = PACK.Packkey
               WHERE LoadPlanDetail.LoadKey = @c_DeleteLoadKey 
         
               SELECT @n_weight = SUM(Weight),
                      @n_cube = SUM(Cube),
                      @n_ordercnt = COUNT(OrderKey)
               FROM LoadPlanDetail WITH (NOLOCK) 
               WHERE LoadKey = @c_DeleteLoadKey
         
               SELECT @n_custcnt = COUNT(DISTINCT ORDERS.ConsigneeKey)
               FROM LoadPlanDetail WITH (NOLOCK)
               JOIN ORDERS WITH (NOLOCK) ON  LoadPlanDetail.OrderKey = ORDERS.OrderKey
               WHERE LoadPlanDetail.LoadKey = @c_DeleteLoadKey

               SET  @n_casecnt   = ISNULL(@n_casecnt,0) 
               SET  @n_weight    = ISNULL(@n_weight,0)
               SET  @n_cube      = ISNULL(@n_cube,0)
               SET  @n_ordercnt  = ISNULL(@n_ordercnt,0)
               SET  @n_palletcnt = ISNULL(@n_palletcnt,0)
               SET  @n_custcnt   = ISNULL(@n_custcnt,0)               
            END 
            ELSE 
            BEGIN 
               SET  @n_casecnt   =  0
               SET  @n_weight    =  0
               SET  @n_cube      =  0
               SET  @n_ordercnt  =  0
               SET  @n_palletcnt =  0
               SET  @n_custcnt   =  0
            END 

      	   SELECT @c_LP_Min_Status = MIN(STATUS), 
      	          @c_LP_Max_Status = MAX(STATUS) 
      	   FROM   LoadPlanDetail AS lpd WITH (NOLOCK)
      	   WHERE  lpd.LoadKey = @c_DeleteLoadKey 
      	   AND    lpd.[Status] NOT IN ('CANC') 
      	
      	   SELECT @c_LP_Cur_Status = [Status]
      	   FROM   LoadPlan AS lp WITH (NOLOCK)
      	   WHERE  lp.LoadKey = @c_DeleteLoadKey
      	
            SET @c_LP_New_Status = CASE
                                      WHEN @c_LP_Max_Status = '0' THEN '0'
                                      WHEN @c_LP_Min_Status = '0' and @c_LP_Max_Status IN ('1','2')
                                         THEN '1'
                                      WHEN @c_LP_Min_Status IN ('0','1','2') AND @c_LP_Max_Status IN ('3','5')
                                         THEN '3'
                                      ELSE @c_LP_Min_Status
                                   END     
            
            IF @cDoNotCalcLPAllocInfo <> '1'
            BEGIN
               UPDATE LoadPlan  
                  SET CustCnt   = @n_custcnt,
                        OrderCnt  = @n_ordercnt,
                        [Weight]  = @n_weight,
                        [Cube]    = @n_cube,
                        PalletCnt = @n_palletcnt,
                        CaseCnt   = @n_casecnt, 
                        [Status]  = @c_LP_New_Status 
                  WHERE LoadPlan.LoadKey = @c_DeleteLoadKey
         
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72009  
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                                    + ': Update Failed On Table LoadPlan. (ntrLoadPlanDetailAdd)' 
                                    + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END             	
            END    
            ELSE 
            BEGIN
            	IF @c_LP_Cur_Status < '5' AND @c_LP_Cur_Status <> @c_LP_New_Status
            	BEGIN
                  UPDATE LoadPlan  
                     SET [Status]  = @c_LP_New_Status, 
                         EditDate  = GETDATE(), 
                         EditWho = SUSER_SNAME(), 
                         TrafficCop = NULL  
                     WHERE LoadPlan.LoadKey = @c_DeleteLoadKey
         
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72009  
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                                       + ': Update Failed On Table LoadPlan. (ntrLoadPlanDetailAdd)' 
                                       + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END             		
            	END            	
            END                                     
         END -- If Loadplan Detail Exists
   
         FETCH NEXT FROM CUR_DELETED_LOADKEY INTO @c_DeleteLoadKey 
      END -- WHILE 
      CLOSE CUR_DELETED_LOADKEY
      DEALLOCATE CUR_DELETED_LOADKEY
   END -- IF @n_continue = 1 or @n_continue = 2
   
   /* Added By SHONG ON 19th Mar 2010 */
   /* Delete PickHeader Record When Loadplan Detail Deleted */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_DelLoadKey             NVARCHAR(10),
              @c_DelOrderKey            NVARCHAR(10), 
              @cKeepPickHDWhenLpdDelete NVARCHAR(10),  -- SHONG01 
              @c_PickSlipNo             NVARCHAR(10)  
              
      DECLARE CUR_DELETED_LP_LINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DEL.LOADKEY, DEL.ORDERKEY, ORD.StorerKey  
      FROM DELETED DEL  
      JOIN ORDERS AS ORD WITH (NOLOCK) ON ORD.OrderKey = DEL.OrderKey  
      
      OPEN CUR_DELETED_LP_LINE
      
      FETCH NEXT FROM CUR_DELETED_LP_LINE INTO @c_DelLoadKey, @c_DelOrderKey, @c_StorerKey 
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF EXISTS(SELECT 1 FROM PICKHEADER WITH (NOLOCK) 
                   WHERE ExternOrderKey = @c_DelLoadKey 
                   AND OrderKey = @c_DelOrderKey)
         BEGIN
         	-- SHONG01
         	SET @cKeepPickHDWhenLpdDelete = ''  

            SELECT @cKeepPickHDWhenLpdDelete = ISNULL(sValue, '0')   
            FROM  STORERCONFIG WITH (NOLOCK)   
            WHERE StorerKey = @c_StorerKey   
            AND   ConfigKey = 'KeepPickHDWhenLpdDelete'   
            AND   sVAlue = '1' 
      
            IF @cKeepPickHDWhenLpdDelete <> '1'
            BEGIN
               DELETE FROM PICKHEADER 
               WHERE ExternOrderKey = @c_DelLoadKey 
                 AND OrderKey = @c_DelOrderKey             	
            END
            ELSE 
            BEGIN
            	IF EXISTS(SELECT 1 FROM PICKHEADER WITH (NOLOCK) 
      	          WHERE OrderKey = @c_DelOrderKey 
      	          AND   ExternOrderKey = @c_DelLoadKey)
               BEGIN
               	DECLARE DEL_PickSlipNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               	SELECT p.PickHeaderKey 
               	FROM PICKHEADER AS p WITH (NOLOCK)
               	WHERE p.ExternOrderKey = @c_DelLoadKey 
               	AND   p.OrderKey = @c_DelOrderKey
               	
               	OPEN DEL_PickSlipNo 
               	FETCH NEXT FROM DEL_PickSlipNo INTO @c_PickSlipNo 
               	WHILE @@FETCH_STATUS = 0 
               	BEGIN
            	      UPDATE PICKHEADER 
            	       SET ExternOrderKey = '', 
            	           TrafficCop = NULL, 
            	           EditDate = GETDATE(), 
            	           EditWho = SUSER_SNAME() 
            	      WHERE ExternOrderKey = @c_DelLoadKey 
            	        AND OrderKey = @c_DelOrderKey  
            	        AND PickHeaderKey = @c_PickSlipNo  
            	   
            	      IF EXISTS(SELECT 1 FROM PackHeader AS ph WITH (NOLOCK)
            	                WHERE ph.PickSlipNo = @c_PickSlipNo 
            	                AND   ph.LoadKey = @c_DelLoadKey 
            	                AND   ph.OrderKey = @c_DelOrderKey)
            	      BEGIN
            	   	   UPDATE PackHeader  
            	   	      SET LoadKey = ''
            	   	   WHERE PickSlipNo = @c_PickSlipNo
            	   	            	   	
            	      END -- PackHeader 
            	      IF EXISTS(SELECT 1 FROM RefKeyLookup AS rkl WITH (NOLOCK)
            	                WHERE rkl.Pickslipno = @c_PickSlipNo 
            	                AND rkl.OrderKey = @c_DelOrderKey 
            	                AND rkl.Loadkey = @c_DelLoadKey)
            	      BEGIN
            	   	   UPDATE RefKeyLookup
            	   	      SET Loadkey = ''
            	   	   WHERE Pickslipno = @c_PickSlipNo 
            	         AND OrderKey = @c_DelOrderKey 
            	         AND Loadkey = @c_DelLoadKey
            	      END -- RefKeyLookup               		
               		
               	   FETCH NEXT FROM DEL_PickSlipNo INTO @c_PickSlipNo 
               	END      	      
               	CLOSE DEL_PickSlipNo
               	DEALLOCATE DEL_PickSlipNo               	        	      
               END -- PICKHEADER
            END -- @cKeepPickHDWhenLpdDelete = 1
         END 
         
         FETCH NEXT FROM CUR_DELETED_LP_LINE INTO @c_DelLoadKey, @c_DelOrderKey, @c_StorerKey  
      END -- WHILE
      CLOSE CUR_DELETED_LP_LINE
      DEALLOCATE CUR_DELETED_LP_LINE
   END    

   -- Start (KHLim01)
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrLoadPlanDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.LoadPlanDetail_DELLOG ( LoadKey, LoadLineNumber )
         SELECT LoadKey, LoadLineNumber FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table ORDERS Failed. (ntrLoadPlanDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01)

   /* #INCLUDE <TRMBODD2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrLoadPlanDetailDelete'
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