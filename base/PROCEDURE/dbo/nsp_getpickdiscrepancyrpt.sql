SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickDiscrepancyRpt                          */
/* Creation Date: 2015-07-28                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  Pickslip for IDSMY                                         */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder59(SOS347270)       */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 09-AUG-2017 Wan01    1.1   WMS-651 - Fixed.                          */
/* 05-AUG-2020 WLChooi  1.2   WMS-14602 - ShowBiggerFont (WL01)         */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickDiscrepancyRpt] (@c_Storerkey NVARCHAR(15)
                                      ,@c_dropid    NVARCHAR(20)) 
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue         int,
           @c_errmsg           NVARCHAR(255),
           @n_err              int,
           @c_ShowBiggerFont   NVARCHAR(10)   --WL01
                                           
   CREATE TABLE #TEMP_PPADISRPT
       ( CCompany         NVARCHAR(45) NULL,
         ConsigneeKey     NVARCHAR(15) NULL,
         DeliveryDate     NVARCHAR(10) NULL,
       	Division         NVARCHAR(10) NULL,
       	ChkDate          DATETIME NULL,
       	PRoute           NVARCHAR(10) NULL, 
       	Refno2           NVARCHAR(30) NULL,
         LoadKey          NVARCHAR(10) NULL,
         SKU              NVARCHAR(20) NULL,
         PPASKU           NVARCHAR(20) NULL, 
         DropID           NVARCHAR(20) NULL,
         PPADropID        NVARCHAR(20) NULL,
         PPAUsername      NVARCHAR(18) NULL,
         Picker           NVARCHAR(18) NULL,
         Ordqty           INT NULL,
         PackQty          INT NULL,
         Chkqty           INT NULL,
         Storerkey        NVARCHAR(15) NULL,   --WL01
         ShowBiggerFont   NVARCHAR(10) NULL    --WL01                                           
       )
   INSERT INTO #TEMP_PPADISRPT
            (CCompany,ConsigneeKey,DeliveryDate,Division,ChkDate,
       	    PRoute,Refno2,LoadKey,SKU,PPASKU,DropID,PPADropID,
             PPAUsername,Picker,Ordqty,PackQty,Chkqty,
             Storerkey, ShowBiggerFont)   --WL01                                                                        
   SELECT DISTINCT ORD.c_company,ORD.ConsigneeKey,CONVERT(NVARCHAR(10),DeliveryDate,103) AS DEL_Date, 
			S.Skugroup,rdtppa.adddate,ph.route,pdet.Refno2,ph.Loadkey,pdet.sku,Rdtppa.Sku,pdet.DropID,Rdtppa.DropID,
			Rdtppa.Username,substring(pdet.addwho,5,18)
         --,orddet.OriginalQty AS ord_qty                                                                         --(Wan01)              
         , ord_qty = (SELECT ISNULL(SUM(OD.OriginalQty),0) FROM ORDERDETAIL OD (NOLOCK)                           --(Wan01)
                      WHERE OD.Orderkey = ORD.Orderkey AND OD.Storerkey = pdet.Storerkey AND OD.Sku =  pdet.SKU)  --(Wan01)
         ,pdet.Qty AS pqty,ISNULL(rdtppa.cqty,0) AS rdtqty
         ,ORD.Storerkey, ISNULL(CL1.Short,'N') AS ShowBiggerFont   --WL01
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.PickSlipNo = PH.PickSlipNo
   JOIN ORDERS ORD WITH (NOLOCK) ON ord.OrderKey = ph.OrderKey
   --JOIN OrderDetail ORDDET WITH (NOLOCK) ON ORDDET.OrderKey = ord.OrderKey AND orddet.sku=pdet.sku        --(Wan01)  
   JOIN SKU S WITH (NOLOCK) ON s.Sku = pdet.SKU AND S.StorerKey = PDET.StorerKey
   LEFT JOIN rdt.Rdtppa rdtppa (NOLOCK) ON rdtppa.DropID = PDET.DropID AND rdtppa.sku=Pdet.sku 
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Code = 'ShowBiggerFont'                 --WL01
                                  AND CL1.Long = 'r_dw_pick_Discrepancy_rpt' AND CL1.Storerkey = ORD.StorerKey   --WL01
                                  AND CL1.Code2 = 'r_dw_pick_Discrepancy_rpt'                                    --WL01
   WHERE ISNULL(pdet.DropID,'') = @c_dropid
   AND ord.StorerKey =@c_Storerkey
   GROUP BY ph.pickslipno,ORD.c_company,ORD.ConsigneeKey,CONVERT(NVARCHAR(10),DeliveryDate,103) , 
			S.Skugroup,rdtppa.adddate,ph.route,pdet.Refno2,ph.Loadkey,pdet.sku,Rdtppa.Sku,pdet.DropID,Rdtppa.DropID,
			Rdtppa.Username,substring(pdet.addwho,5,18)
         --,orddet.OriginalQty                                                                                    --(Wan01)
         ,ord.orderkey                                                                                            --(Wan01)
         ,pdet.storerkey                                                                                          --(Wan01)
         ,pdet.Qty  ,rdtppa.cqty
         ,ORD.Storerkey, ISNULL(CL1.Short,'N')   --WL01    
   UNION
   SELECT DISTINCT ORD.c_company,ORD.ConsigneeKey,CONVERT(NVARCHAR(10),DeliveryDate,103) AS DEL_Date, 
			S.Skugroup,rdtppa.adddate,ph.route,pdet.Refno2,ph.Loadkey,pdet.sku,Rdtppa.Sku,pdet.DropID,Rdtppa.DropID,
			Rdtppa.Username,substring(pdet.addwho,5,18)
         --,ISNULL(orddet.OriginalQty,0) AS ord_qty                                                               --(Wan01)
         , ord_qty = (SELECT ISNULL(SUM(OD.OriginalQty),0) FROM ORDERDETAIL OD (NOLOCK)                           --(Wan01)
                      WHERE OD.Orderkey = ORD.Orderkey AND OD.Storerkey = pdet.Storerkey AND OD.Sku =  pdet.SKU)  --(Wan01)
         ,ISNULL(pdet.Qty,0) AS pqty,ISNULL(rdtppa.cqty,0) AS rdtqty
         ,ORD.Storerkey, ISNULL(CL1.Short,'N') AS ShowBiggerFont   --WL01
   FROM PACKHEADER PH WITH (NOLOCK)
   LEFT JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.PickSlipNo = PH.PickSlipNo
   LEFT JOIN ORDERS ORD WITH (NOLOCK) ON ord.OrderKey = ph.OrderKey
   --LEFT JOIN OrderDetail ORDDET WITH (NOLOCK) ON ORDDET.OrderKey = ord.OrderKey AND orddet.sku=pdet.sku   --(Wan01)
   LEFT JOIN SKU S WITH (NOLOCK) ON s.Sku = pdet.SKU AND S.StorerKey = PDET.StorerKey
   RIGHT JOIN rdt.Rdtppa rdtppa (NOLOCK) ON rdtppa.DropID = PDET.DropID AND rdtppa.sku=Pdet.sku 
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Code = 'ShowBiggerFont'                 --WL01
                                  AND CL1.Long = 'r_dw_pick_Discrepancy_rpt' AND CL1.Storerkey = ORD.StorerKey   --WL01
                                  AND CL1.Code2 = 'r_dw_pick_Discrepancy_rpt'                                    --WL01
   WHERE ISNULL(rdtppa.DropID,'') = @c_dropid
   AND rdtppa.StorerKey =@c_Storerkey
   GROUP BY ph.pickslipno,ORD.c_company,ORD.ConsigneeKey,CONVERT(NVARCHAR(10),DeliveryDate,103) , 
			S.Skugroup,rdtppa.adddate,ph.route,pdet.Refno2,ph.Loadkey,pdet.sku,Rdtppa.Sku,pdet.DropID,Rdtppa.DropID,
			Rdtppa.Username,substring(pdet.addwho,5,18)
         --,orddet.OriginalQty                                                                                    --(Wan01)
         ,ord.orderkey                                                                                            --(Wan01)
         ,pdet.storerkey                                                                                          --(Wan01)
         ,pdet.Qty  ,rdtppa.cqty 	
         ,ORD.Storerkey, ISNULL(CL1.Short,'N')   --WL01  
   ORDER BY PDET.SKU             
   
   --WL01 START
   SELECT @c_ShowBiggerFont = ShowBiggerFont
   FROM #TEMP_PPADISRPT

   IF @c_ShowBiggerFont = 'Y'
   BEGIN
      SELECT CCompany      
           , ConsigneeKey  
           , DeliveryDate  
           , Division      
           , ChkDate       
           , PRoute        
           , Refno2        
           , LoadKey       
           , SKU           
           , PPASKU        
           , DropID        
           , PPADropID     
           , PPAUsername   
           , Picker        
           , SUM(Ordqty) AS Ordqty   
           , SUM(PackQty) AS PackQty        
           , Chkqty        
           , Storerkey     
           , ShowBiggerFont
      FROM #TEMP_PPADISRPT  
      GROUP BY CCompany      
             , ConsigneeKey  
             , DeliveryDate  
             , Division      
             , ChkDate       
             , PRoute        
             , Refno2        
             , LoadKey       
             , SKU           
             , PPASKU        
             , DropID        
             , PPADropID     
             , PPAUsername   
             , Picker           
             , Chkqty        
             , Storerkey     
             , ShowBiggerFont
      ORDER BY CASE WHEN ISNULL(DropID,'') = '' THEN 1 ELSE 0 END ,SKU
   END
   ELSE
   BEGIN
      SELECT * FROM #TEMP_PPADISRPT  
      ORDER BY CASE WHEN ISNULL(DropID,'') = '' THEN 1 ELSE 0 END ,SKU
   END
   --WL01 END
     
   DROP Table #TEMP_PPADISRPT  
END

GO