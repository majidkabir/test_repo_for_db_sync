SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Trigger: ntrMBOLDetailDelete                                          */  
/* Creation Date:                                                        */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Input Parameters:                                                     */  
/*                                                                       */  
/* Output Parameters:                                                    */  
/*                                                                       */  
/* Return Status:                                                        */  
/*                                                                       */  
/* Usage:                                                                */  
/*                                                                       */  
/* Local Variables:                                                      */  
/*                                                                       */  
/* Called By: Delete Mboldetail                                          */  
/*                                                                       */  
/* PVCS Version: 2.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver  Purposes                                    */  
/* 3 MArch 2005 YTWan        Empty orderdetail's MBOLKey  WHEN           */  
/*                           Orderdetail'sLoadKey is empty               */  
/* 04-Jan-2008  SHONG        Bug Fixing - Wrong Formula for Pallet Cnt   */  
/*                           Calculation SOS#95432                       */  
/* 16-Sep-2009  Leong   1.1  SOS147150 - Update OrderDetail before Orders*/  
/* 05-May-2010  NJOW01  1.2  168916 - update total carton to mbol        */  
/*                           depend on mbol.userdefine09                 */  
/* 07-Jul-2010  TLTING  1.3  SOS147150 - Change orderdetail update       */  
/*  9-Jun-2011  KHLim01 1.4  Insert Delete log                           */  
/* 14-Jul-2011  KHLim02 1.5  GetRight for Delete log                     */  
/* 14-Mar-2012  KHLim03 1.6  Update EditDate                             */  
/* 06-APR-2012  YTWan   1.7  SOS#238876:ReplaceUSAMBOL.                  */  
/*                            Calculate NoofCartonPacked. (Wan01)        */  
/* 30-Apr-2012  SHONG   1.7   CustCnt Should using Count Consignee       */  
/*                            Cater ConsoOrderKey                        */  
/* 02-May-2012  Leong   1.8   SOS# 242479 - Add @n_Continue check        */  
/* 12-Sep-2012  SHONG   1.9   Prevent Splitted Order MBOL Accidentally   */  
/*                            Deleted by someone SOS#256080              */   
/* 10-Dec-2012  KHLim   1.10  SOS#264269:Log OrderKey into DELLOG (KH01) */  
/* 22-APR-2014  YTWan   1.11  SOS#294825 ANF - MBOL Creation.(Wan02)     */  
/* 28-JUL-2017  Wan03   2.0   WMS-1916 - WMS Storerconfig for Copy       */  
/*                            totalcarton toctncnt1 in mboldetail        */  
/* 28-May-2020  Shong   3.1   WMS-13444 Auto Create POD record after     */  
/*                            MBOL creation  (SWT01)                     */  
/*************************************************************************/  
  
CREATE TRIGGER [dbo].[ntrMBOLDetailDelete]  
ON [dbo].[MBOLDETAIL]  
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
  
   DECLARE @b_Success   Int       -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err       Int       -- Error number returned by stored procedure OR this trigger  
         , @c_errmsg    NVARCHAR(250) -- Error message returned by stored procedure OR this trigger  
         , @n_Continue  Int       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing  
         , @n_starttcnt Int       -- Holds the current transaction count  
         , @n_cnt       Int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.  
         , @c_authority NVARCHAR(1)    -- KHLim02  
         , @n_TtlCnts   Int        --(Wan01)  
         , @c_MBOLKey   NVARCHAR(10)   --(Wan01)  
         , @n_CustCnt   Int  
         , @c_Facility  NVARCHAR(5)    --(Wan02)  
         , @c_CreatePopulateChildORD   NVARCHAR(10)   --(Wan02)  
  
   SET @n_TtlCnts = 0  --(Wan01)  
   SET @c_MBOLKey = '' --(Wan01)  
   SET @c_Facility= '' --(Wan02)  
   SET @c_CreatePopulateChildORD = ''  --(Wan02)  
  
   SELECT @n_Continue = 1, @n_starttcnt = @@TRANCOUNT  
  
   /* #INCLUDE <TRMBODD1.SQL> */  
   IF (SELECT COUNT(*) FROM DELETED) = (SELECT COUNT(*) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN  
      SELECT @n_Continue = 4  
   END  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM MBOL WITH (NOLOCK), DELETED  
                  WHERE MBOL.MBOLKey = DELETED.MBOLKey  
                  AND MBOL.Status = '9')  
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @n_err = 72600  
         SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': MBOL.Status = SHIPPED. DELETE rejected. (ntrMBOLDetailDelete)'  
      END  
   END  
  
   -- Added By SHONG on 12-Sep-2012, to Prevent Splitted Order MBOL Accidentally Deleted by someone  
   IF @n_Continue = 1 OR @n_Continue = 2    
   BEGIN    
      IF EXISTS(SELECT 1 FROM RDT.RDTScanToTruck STT WITH (NOLOCK)   
                JOIN DELETED DEL ON STT.MbolKey = DEL.MBOLKey AND STT.Status IN ('3', '9' )  
                JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = DEL.OrderKey AND OD.UserDefine10 <> '' AND OD.UserDefine10 IS NOT NULL)  
      BEGIN  
         SELECT @n_Continue = 3    
         SELECT @n_err = 72610   
         SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': RDTScanToTruck.Status = 9. DELETE rejected. (ntrMBOLDetailDelete)'    
      END   
   END    
  
  --(Wan03) - START  
   IF @n_continue=1 or @n_continue=2            
   BEGIN  
      IF EXISTS (SELECT 1 FROM DELETED d    
                 JOIN ORDERS O WITH (NOLOCK) ON (D.Orderkey = O.Orderkey)  
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
                   'DELETE'  --@c_Action  
                 , @b_Success  OUTPUT    
                 , @n_Err      OUTPUT     
                 , @c_ErrMsg   OUTPUT    
     
         IF @b_success <> 1    
         BEGIN    
            SELECT @n_continue = 3    
                  ,@c_errmsg = 'ntrMBOLDetailDelete ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  
         END    
           
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL  
            DROP TABLE #INSERTED  
     
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL  
            DROP TABLE #DELETED  
      END  
   END     
   --(Wan03) - END   
  
   --(Wan02) - START // Prevent delete order from MBOLDETAIL for Created Child Order  
   IF @n_Continue = 1 OR @n_Continue = 2    
   BEGIN  
      SELECT @c_Facility = MBOL.Facility  
      FROM DELETED  
      JOIN MBOL WITH (NOLOCK) ON (DELETED.MBOLKey = MBOL.MBOLKey)  
        
      SET @b_success = 0   
      SET @c_CreatePopulateChildORD = '0'      
      EXECUTE nspGetRight  @c_Facility                -- facility  
                        ,  NULL                       -- Storerkey  
                        ,  NULL                       -- Sku  
                        ,  'CreatePopulateChildORD'   -- Configkey  
                        ,  @b_success                 OUTPUT   
                        ,  @c_CreatePopulateChildORD  OUTPUT   
                        ,  @n_err                     OUTPUT   
                        ,  @c_errmsg                  OUTPUT  
      IF @b_success <> 1  
      BEGIN  
         SET @n_Continue = 3  
         SET @c_errmsg = 'ntrMBOLDETAILDelete' + RTRIM(@c_errmsg)  
      END  
      ELSE  
      IF @c_CreatePopulateChildORD = '1'           
      BEGIN  
         IF EXISTS ( SELECT 1  
                     FROM DELETED  
                     JOIN ORDERS      WITH (NOLOCK) ON (DELETED.Orderkey = ORDERS.Orderkey)  
                     JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey  = ORDERDETAIL.Orderkey)  
                     WHERE RDD = 'SplitOrder'  
                     AND ORDERDETAIL.UserDefine09 <> ''  
                     AND ORDERDETAIL.UserDefine09 IS NOT NULL  
                     AND ORDERDETAIL.UserDefine10 <> ''  
                     AND ORDERDETAIL.UserDefine10 IS NOT NULL   
                    )  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err = 72611  
            SET @c_errmsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Delete Child Order. DELETE rejected (ntrMBOLDETAILDelete)'   
         END  
      END  
   END  
   --(Wan02) - END  
  
   --(Wan01) - START  
   IF @n_Continue = 1 OR @n_Continue = 2 -- SOS# 242479  
   BEGIN  
      SELECT @c_MBOLKey = DELETED.MBOLKey  
            ,@n_TtlCnts = SUM(MBOLDETAIL.TotalCartons)  
            ,@n_CustCnt = COUNT(DISTINCT O.ConsigneeKey)  
      FROM DELETED  
      JOIN MBOLDETAIL WITH (NOLOCK) ON DELETED.MBOLKey = MBOLDETAIL.MBOLKey  
      JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = MBOLDETAIL.OrderKey  
      GROUP BY DELETED.MBOLKey  
  
      UPDATE MBOL WITH (ROWLOCK)  
      SET NoofCartonPacked = @n_TtlCnts  
         , EditWho = SUSER_SNAME()  
         , EditDate = GETDATE()  
         , Trafficcop = NULL  
         , CustCnt = @n_CustCnt  
      WHERE MBOLKey = @c_MBOLKey  
  
      SELECT @n_err = @@ERROR  
  
      IF @n_err <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 72601  
         SET @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Update Failed On Table MBOL. (ntrMBOLDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
      END  
   END  
   --(Wan01) - END  
  
   /**** To Calculate Weight, Cube, Pallet, CASE AND Customer Cnt ****/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      DECLARE @n_casecnt   Int  
            , @n_palletcnt Int  
  
      --  Bug Fixed by SHONG SOS#95432  
      --  Original: @n_palletcnt = SUM(((ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) * SKU.StdCube) / 1),  
      SELECT @n_palletcnt = SUM((ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) / (CASE WHEN PACK.Pallet = 0  
                                                                                           THEN 1  
                                                                                           ELSE PACK.Pallet  
                                                                                      END)),  
             @n_casecnt = SUM((ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) / (CASE WHEN PACK.CaseCnt > 0  
                                                                                         THEN pack.casecnt  
                                                                                         ELSE NULL  
                                                                                    END))  
      FROM ORDERDETAIL WITH (NOLOCK)  
      JOIN DELETED ON (ORDERDETAIL.OrderKey = DELETED.OrderKey)  
      JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.SKU = SKU.SKU)  
      JOIN PACK WITH (NOLOCK) ON (ORDERDETAIL.Packkey = PACK.Packkey)  
  
      IF @n_casecnt = NULL  
         SELECT @n_casecnt = 0  
  
      IF @n_palletcnt = NULL  
         SELECT @n_palletcnt = 0  
  
      UPDATE MBOL  
      SET Weight  = MBOL.Weight - DELETED.Weight,  
          Cube    = MBOL.Cube - DELETED.Cube,  
          PalletCnt = PalletCnt - @n_palletcnt,  
          CaseCnt = CaseCnt - @n_casecnt,  
          MBOL.TrafficCop = NULL  
      FROM MBOL, DELETED  
      WHERE MBOL.MBOLKey = DELETED.MBOLKey  
         AND (DELETED.OrderKey <> '' OR DELETED.OrderKey <> NULL)  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250), @n_err), @n_err = 72602  
         SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Update Failed On Table MBOL. (ntrMBOLDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'  
      END  
   END  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      --SOS147150  
      UPDATE OrderDetail  
      SET MBOLKey = '',  
          EditDate = GETDATE(), -- KHLim03  
          TrafficCop = NULL  
      WHERE Exists ( SELECT 1 FROM DELETED  
                     WHERE  DELETED.OrderKey = OrderDetail.OrderKey )  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250), @n_err), @n_err = 72603  
         SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Update Failed On Table OrderDetail. (ntrMBOLDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'  
      END  
   END  
  
   --SOS147150  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      UPDATE ORDERS  
      SET MBOLKey = '',  
          EditDate = GETDATE(), -- KHLim03  
          TrafficCop = NULL  
      FROM ORDERS WITH (NOLOCK), DELETED  
      WHERE ORDERS.OrderKey = DELETED.OrderKey  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250), @n_err), @n_err = 72604  
         SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Update Failed On Table ORDERS. (ntrMBOLDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'  
      END  
   END  
  
   --Added By Vicky 17 July 2002  
   --Patch FROM IDSMY SOS 6040  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      UPDATE LOADPLAN  
      SET MBOLKey = '',  
          EditDate = GETDATE(), -- KHLim03  
          TrafficCop = NULL  
      FROM LOADPLAN WITH (NOLOCK)  
      JOIN DELETED ON LOADPLAN.MBOLKey = DELETED.MBOLKey  
                  AND LOADPLAN.LoadKey = DELETED.LoadKey  
      WHERE NOT EXISTS(SELECT 1 FROM MBOLDETAIL WITH (NOLOCK) WHERE MBOLDETAIL.MBOLKey = DELETED.MBOLKey  
                       AND MBOLDETAIL.LoadKey = DELETED.LoadKey)  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250), @n_err), @n_err = 72605  
         SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Update Failed On Table LoadPlan. (ntrMBOLDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'  
      END  
   END  
   --END Add  
  
   -- wally 8.may.2003  
   -- trigantic control: delete POD record in CASE it was created  
   -- start01  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      DELETE POD  
      FROM POD P JOIN DELETED D ON P.MBOLKey = D.MBOLKey  
                  AND P.ORDERKEY = D.ORDERKEY  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250), @n_err), @n_err = 72606  
         SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Delete Failed on Table POD. (ntrMBOLDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'  
      END  
   END  
   -- end01  
  
   --SOS#168916  NJOW01  
   IF (@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN  
      IF EXISTS(SELECT 1  
                FROM   DELETED D  
                JOIN   Orders O WITH (NOLOCK) ON (O.OrderKey = D.OrderKey)  
                JOIN   StorerConfig S WITH (NOLOCK) ON (S.StorerKey = O.StorerKey)  
                WHERE  S.sValue NOT IN ('0','')  
                AND    S.Configkey = 'MBOLDEFAULT')  
      BEGIN  
         UPDATE MBOL WITH (ROWLOCK)  
         SET NoOfIDSCarton = CASE WHEN MBOL.userdefine09 = 'IDS'  
                                  THEN NoOfIDSCarton - (SELECT SUM(DELETED.TotalCartons) FROM DELETED WHERE DELETED.MBOLKey = MBOL.MBOLKey)  
                             ELSE 0 END,  
             NoOfCustomerCarton = CASE WHEN MBOL.userdefine09 = 'CUSTOMER'  
                                       THEN NoOfCustomerCarton - (SELECT SUM(DELETED.TotalCartons) FROM DELETED WHERE DELETED.MBOLKey = MBOL.MBOLKey)  
                                  ELSE 0 END,  
             EditDate = GETDATE(), -- KHLim03  
             TrafficCop = NULL  
         FROM MBOL  
         WHERE MBOL.MBOLKey IN (SELECT DISTINCT MBOLKey FROM DELETED)  
  
         SELECT @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_Continue = 3  
            SELECT @c_errmsg = CONVERT(Char(250), @n_err), @n_err = 72607  
            SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Update Failed on Table MBOL. (ntrMBOLDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' )'  
         END  
      END  
   END  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      DECLARE @tPack TABLE  
         (PickSlipNo NVARCHAR(10),  
          LabelNo    NVARCHAR(20),  
          CartonNo   Int,  
          [WEIGHT]   REAL,  
          [CUBE]     REAL)  
  
      DECLARE CUR_DELMBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT MBOLKey FROM DELETED  
  
      OPEN CUR_DELMBOL  
      FETCH NEXT FROM CUR_DELMBOL INTO @c_MBOLKey  
  
      WHILE @@FETCH_STATUS <>  -1  
      BEGIN  
         IF EXISTS(SELECT 1 FROM ORDERDETAIL O WITH (NOLOCK) WHERE O.MBOLKey = @c_MBOLKey  
                   AND O.ConsoOrderKey IS NOT NULL AND O.ConsoOrderKey <> '')  
         BEGIN  
            INSERT INTO @tPack (PickSlipNo, LabelNo, CartonNo, [WEIGHT], [CUBE])  
            SELECT DISTINCT P.PickSlipNo, PD.LabelNo, PD.CartonNo,0, 0  
            FROM   PICKDETAIL p WITH (NOLOCK)  
            JOIN   PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = P.PickSlipNo AND PD.DropID = P.DropID)  
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
               SET [Weight]  =  PK.WEIGHT, MBOL.[Cube] = PK.Cube, MBOL.CaseCnt = PK.CaseCnt,  
                   TrafficCop=NULL  
            FROM MBOL  
            JOIN (SELECT @c_MBOLKey AS MBOLKey, SUM(WEIGHT) AS Weight, SUM(CUBE) AS Cube, COUNT(*) AS CaseCnt  
                  FROM @tPack) AS PK ON MBOL.MBOLKey = PK.MBOLKey  
         END  
  
         DELETE FROM @tPack  
  
         FETCH NEXT FROM CUR_DELMBOL INTO @c_MBOLKey  
      END -- While CUR_DELMBOL  
      CLOSE CUR_DELMBOL  
      DEALLOCATE CUR_DELMBOL  
  
   END  
  
   -- Start (KHLim01)  
   IF @n_Continue = 1 OR @n_Continue = 2  
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
         SELECT @n_Continue = 3  
              , @c_errmsg = 'ntrMBOLDETAILDelete' + RTRIM(@c_errmsg)  
      END  
      ELSE  
      IF @c_authority = '1'         --    END   (KHLim02)  
      BEGIN  
         INSERT INTO dbo.MBOLDETAIL_DELLOG ( MBOLKey, MbolLineNumber, OrderKey ) --KH01  
         SELECT MBOLKey, MbolLineNumber, OrderKey FROM DELETED --KH01  
  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_Continue = 3  
            SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 72607  
            SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Delete Trigger On Table MBOLDetail Failed. (ntrMBOLDETAILDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' )'  
         END  
      END  
   END  
   -- END (KHLim01)  
     
     
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      DECLARE   
              @c_POD_Authority    NVARCHAR(1)  = '0'   -- (SWT01)  
            , @c_POD_Option01     NVARCHAR(20) = ''   -- (SWT01)   
            , @c_MbolLineNumber   NVARCHAR(5)  = ''  
            , @c_StorerKey        NVARCHAR(15) = ''  
              
        
      DECLARE CUR_DELETE_MBOL_LN CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT MD.MbolKey, MD.MbolLineNumber, o.StorerKey, o.Facility  
      FROM DELETED MD WITH (NOLOCK)  
      JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = MD.OrderKey  
        
      OPEN CUR_DELETE_MBOL_LN  
        
      FETCH FROM CUR_DELETE_MBOL_LN INTO @c_MbolKey, @c_MbolLineNumber, @c_StorerKey, @c_Facility  
        
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         SET @b_success = 0  
         SET @c_POD_Option01=''  
         SET @c_POD_Authority = ''  
              
         EXECUTE nspGetRight   
             @c_Facility  = @c_Facility -- facility  
            ,@c_StorerKey = @c_StorerKey -- Storerkey -- SOS40271  
            ,@c_sku       = NULL         -- Sku  
            ,@c_ConfigKey = 'POD'        -- Configkey  
            ,@b_Success   = @b_success       OUTPUT  
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
            IF NOT EXISTS ( SELECT 1 FROM POD WITH (NOLOCK) WHERE MBOLKey = @c_MBOLKey AND Mbollinenumber = @c_MbolLineNumber)  
            BEGIN  
               SET @b_success = 0  
  
               DELETE FROM POD  
               WHERE MBOLKey = @c_MBOLKey   
               AND Mbollinenumber = @c_MbolLineNumber  
                 
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807  
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))  
                                    + ': Delete Failed On Table POD. (ntrMBOLDetailDelete)'  
                                    + ' ( SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg), '') + ' ) '  
               END  
            END  
         END -- POD Authority = 1 -- (SWT01)  
        
        
         FETCH FROM CUR_DELETE_MBOL_LN INTO @c_MbolKey, @c_MbolLineNumber, @c_StorerKey, @c_Facility  
      END  
        
      CLOSE CUR_DELETE_MBOL_LN  
      DEALLOCATE CUR_DELETE_MBOL_LN  
        
        
   END     
  
   /* #INCLUDE <TRMBODD2.SQL> */  
   IF @n_Continue = 3  -- Error Occured - Process AND Return  
   BEGIN  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrMBOLDetailDelete'  
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