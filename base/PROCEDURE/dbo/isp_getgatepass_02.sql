SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetGatePass_02                                 */
/* Creation Date: 2020-07-08                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-13948 - [PH] - Adidas MBOL                              */
/*                                                                      */
/* Input Parameters:  @c_mbolkey  - MBOL Key                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_gatepass_02                        */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC from MBOL                                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_GetGatePass_02] (@c_mbolkey NVARCHAR(10)) 
AS
BEGIN
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue          INT,
             @c_errmsg          NVARCHAR(255),
             @b_success         INT,
             @n_err             INT,
             @n_cnt             INT,
             @c_OtherReference  NVARCHAR(30),
             @c_facility        NVARCHAR(5),
             @c_keyname         NVARCHAR(30),
             @c_printflag       NVARCHAR(1)
   
    SELECT @n_continue = 1, @n_err = 0, @c_errmsg = '', @b_success = 1, @n_cnt = 0, @c_printflag = 'Y'
            
   SELECT @c_OtherReference = MBOL.OtherReference, @c_facility = MBOL.Facility
   FROM MBOL (NOLOCK)
   WHERE Mbolkey = @c_mbolkey
   
   SELECT @n_cnt = @@ROWCOUNT
   
   IF ISNULL(RTRIM(@c_OtherReference),'') = '' AND @n_cnt > 0
   BEGIN
       SELECT @c_printflag = 'N'
       
       SELECT @c_keyname = Code
       FROM CODELKUP (NOLOCK)
       WHERE ListName = 'GP_NCOUNT' 
       AND Short = @c_facility
      
       IF ISNULL(RTRIM(@c_keyname),'') = ''
       BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62313   
        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': CODELKUP LISTNAME GP_NCOUNT Retrieving Failed For Facility '+RTRIM(@c_facility)+' (isp_GetGatePass_02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
       END 
       
       IF @n_continue = 1 or @n_continue = 2
       BEGIN
          EXECUTE nspg_GetKey 
               @c_keyname,
               10,   
               @c_OtherReference OUTPUT,
               @b_success      OUTPUT,
               @n_err          OUTPUT,
               @c_errmsg       OUTPUT
               
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3
          END
          ELSE
          BEGIN
              --BEGIN TRAN
              UPDATE MBOL WITH (ROWLOCK)
              SET OtherReference = @c_OtherReference,
                  EditDate   = GETDATE(),                                
                  TrafficCop = NULL                
              WHERE Mbolkey = @c_mbolkey
              
              SELECT @n_err = @@ERROR
              IF @n_err <> 0 
              --BEGIN
                 --WHILE @@TRANCOUNT > 0 
                       --COMMIT TRAN 
              --END  
              --ELSE
                BEGIN
                   --ROLLBACK TRAN 
                   SELECT @n_continue = 3
                   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62314   
                   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update MBOL Failed. (isp_GetGatePass_02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                END
              END
           END
   END
                                    
   IF @n_continue = 1 OR @n_continue = 2                               
   BEGIN
   SELECT MBOL.mbolkey
          , MBOL.facility
          , FACILITY.descr                             
          , MBOL.carrieragent                                
          , HAULER.Company 
          , MBOL.vesselqualifier AS trucktype 
          , MBOL.vessel AS truckno
          , MBOL.drivername
          , MBOL.departuredate
          , ORDERS.Consigneekey  
          , ORDERS.c_company  
          , ORDERS.route 
          , ROUTEMASTER.Descr 
          , @c_OtherReference AS OtherReference 
          , MBOL.UserDefine04                             
          , MBOL.SealNo                                      
          , MBOL.ContainerNo                                 
          , MBOLDETAIL.invoiceno
          , ORDERS.externorderkey  
          , MBOL.editwho
          , ROUND(SUM(CASE WHEN PACK.casecnt > 0 THEN PICKDETAIL.qty / PACK.casecnt ELSE 0 END),2) AS totalcase
          , ROUND(SUM(CASE WHEN PACK.casecnt > 0 THEN ROUND(SKU.STDGROSSWGT * PACK.CaseCnt,3) * (PICKDETAIL.qty / PACK.casecnt) ELSE 0 END),2) AS grossweight
          , @c_printflag AS PrintFlag
          , ROUND(SUM(PICKDETAIL.qty * SKU.Stdcube),4) AS CBM   
          , ORDERS.Loadkey  
          , LEFT(ISNULL(MBOL.Remarks,''),250) AS Remark1  
          , SUBSTRING(ISNULL(MBOL.Remarks,''),251,250) AS Remark2  
          , Loadplan.Externloadkey AS LEXTLoadKey       
          , CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS HideExternLoadkey  
          , SUM(PICKDETAIL.qty) AS totalEaches
          , COUNT(DISTINCT LOTT.Lottable10) AS TTLCTN
     FROM PICKDETAIL (NOLOCK) 
     INNER JOIN ORDERDETAIL (NOLOCK) ON (PICKDETAIL.orderkey  = ORDERDETAIL.Orderkey 
                                         AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber)
     INNER JOIN ORDERS (NOLOCK) ON (PICKDETAIL.orderkey = ORDERS.orderkey)
     INNER JOIN SKU (NOLOCK) ON (PICKDETAIL.storerkey = SKU.storerkey
                                 AND PICKDETAIL.Sku = SKU.Sku)
     INNER JOIN PACK (NOLOCK) ON (PICKDETAIL.packkey = PACK.packkey)
     INNER JOIN MBOLDETAIL(NOLOCK) ON  (ORDERDETAIL.Mbolkey =  MBOLDETAIL.mbolkey
                                        AND ORDERDETAIL.loadkey = MBOLDETAIL.Loadkey
                                        AND ORDERDETAIL.orderkey = MBOLDETAIL.OrderKey)
     INNER JOIN MBOL (NOLOCK) ON (MBOLDETAIL.Mbolkey = MBOL.mbolkey)
     INNER JOIN ROUTEMASTER (NOLOCK) ON (ORDERS.route = ROUTEMASTER.route)
     -- LEFT OUTER JOIN STORER HAULER (NOLOCK) ON ('3'+MBOL.Carrierkey = LEFT(HAULER.Type,1)+HAULER.StorerKey)
     LEFT OUTER JOIN STORER HAULER (NOLOCK) ON (MBOL.Carrierkey = HAULER.StorerKey AND LEFT(HAULER.Type,1) = '3')  
     LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'HIDEEXTERNLOADKEY' 
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_gatepass_02' AND ISNULL(CLR.Short,'') <> 'N')  
     INNER JOIN FACILITY (NOLOCK) ON (MBOL.facility = FACILITY.facility)
     JOIN LOADPLAN WITH (NOLOCK)                      
      ON LOADPLAN.loadkey = ORDERDETAIL.loadkey     
     JOIN lotattribute LOTT WITH (NOLOCK) ON LOTT.lot=PICKDETAIL.Lot AND LOTT.sku = PICKDETAIL.sku AND LOTT.Storerkey = PICKDETAIL.Storerkey
     WHERE ORDERDETAIL.mbolkey = @c_mbolkey  AND MBOL.status = '9'
     GROUP BY MBOL.Mbolkey
            , MBOL.facility                
            , FACILITY.descr                                         
            , MBOL.carrieragent                                         
            , HAULER.Company               
            , MBOL.vesselqualifier         
            , MBOL.vessel                  
            , MBOL.drivername              
            , MBOL.departuredate                        
            , ORDERS.Consigneekey  
            , ORDERS.c_company  
            , ORDERS.route                 
            , ROUTEMASTER.Descr            
            , MBOL.UserDefine04            
            , MBOL.SealNo                                    
            , MBOL.ContainerNo                                          
            , MBOLDETAIL.invoiceno         
            , ORDERS.externorderkey           
            , MBOL.editwho
            , ORDERS.Loadkey  
            , LEFT(ISNULL(MBOL.Remarks,''),250)  
            , SUBSTRING(ISNULL(MBOL.Remarks,''),251,250)  
            , Loadplan.Externloadkey                       
            , CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END  
   END
            
   IF @n_continue = 3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetGatePass_02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END                                       

GO