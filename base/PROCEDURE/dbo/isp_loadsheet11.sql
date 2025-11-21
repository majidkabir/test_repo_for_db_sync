SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_LoadSheet11                                         */  
/* Creation Date: 18-May-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-13385 - MYS–ULM–Modify Contract Delivery note to        */
/*                      Outbound Tally Sheet in LoadPlan                */  
/*        :                                                             */  
/* Called By: r_dw_loadsheet11                                          */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 12-Jun-2020  CSCHONG   WMS-13713 add new field (CS01)                */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_LoadSheet11]
            @c_Loadkey    NVARCHAR(10)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  
  
         , @c_Orderkey        NVARCHAR(10)  
         , @c_ExternOrderKey  NVARCHAR(50)  
         , @c_Storerkey       NVARCHAR(15)  

         , @c_RptLogo         NVARCHAR(255)  
         , @c_ecomflag        NVARCHAR(50)
         , @n_MaxLineno       INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_CurrentRec      INT
         , @c_recgroup        INT
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 
   SET @c_RptLogo   = '' 

   SET @n_MaxLineno = 10
   SET @n_MaxId     = 1
   SET @n_MaxRec    = 1
   SET @n_CurrentRec= 1
   SET @c_recgroup  = 1 

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT 
         LPD.LoadKey as loadkey,
         '' AS Orderkey,
         OH.Externorderkey AS Externorderkey,
         OH.Storerkey as storerkey, 
         CONVERT(NVARCHAR(10),OH.Deliverydate, 103) AS DELDate,
         CASE SKU.BUSR5 
            WHEN 'UFR' THEN CONVERT(VARCHAR(10),LOTT.Lottable04,103) 
            WHEN 'UFS' THEN CONVERT(VARCHAR(10),LOTT.Lottable04,103) 
            ELSE '' 
         END as ExpiryDate ,
         OH.c_company as c_company,
         OH.Salesman as Salesman,
         CASE WHEN PAC.CaseCnt > 0 THEN SUM(PD.qty) % CAST(PAC.CaseCnt AS INT) ELSE SUM(PD.qty) END as PQty,
         CASE WHEN PAC.CaseCnt > 0 THEN FLOOR(SUM(PD.qty) / PAC.CaseCnt) ELSE 0 END as PQtyInCS,
         PD.SKU as Sku,
         SKU.Descr as sdescr,
         PAC.CaseCnt as casecnt,
         LOADPLAN.CarrierKey as carrierkey,
         OH.Notes as OHNotes,
         ISNULL(SKU.Altsku,'') as Altsku         --CS01
      INTO #Temp_LoadSheet11
      FROM LOADPLANDETAIL LPD WITH (NOLOCK) 
      INNER JOIN ORDERS OH WITH (NOLOCK) 
         ON (LPD.OrderKey = OH.OrderKey) 
      INNER JOIN ORDERDETAIL OD WITH (NOLOCK) 
         ON (OH.OrderKey = OD.OrderKey AND LPD.LoadKey = OD.LoadKey) 
      INNER JOIN PICKDETAIL AS PD ON PD.Orderkey = OD.OrderKey  
                                  AND PD.sku=OD.sku AND PD.OrderLineNumber = OD.OrderLineNumber  
      INNER JOIN SKU SKU WITH (NOLOCK) 
         ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU) 
      INNER JOIN PACK PAC WITH (NOLOCK) 
         ON (SKU.PackKey = PAC.PackKey) 
      JOIN LOADPLAN WITH (NOLOCK)                     
            ON LOADPLAN.loadkey = OD.loadkey    
      JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (LOTT.Lot=PD.lot) 
      WHERE LPD.LoadKey = @c_Loadkey
      GROUP BY LPD.LoadKey,
         OH.Facility,
         OH.Storerkey, 
         OH.Externorderkey,
         CONVERT(NVARCHAR(10),OH.Deliverydate, 103),
         CASE SKU.BUSR5 
            WHEN 'UFR' THEN CONVERT(VARCHAR(10),LOTT.Lottable04,103) 
            WHEN 'UFS' THEN CONVERT(VARCHAR(10),LOTT.Lottable04,103) 
            ELSE '' 
         END,
         OH.c_company,
         OH.Salesman,
         PD.SKU,
         SKU.Descr,
         PAC.CaseCnt,
         LOADPLAN.CarrierKey,
         OH.Notes,
         ISNULL(SKU.Altsku,'')     --CS01   
      ORDER BY LPD.LoadKey,OH.Externorderkey,OH.Salesman,OH.c_company, PD.SKU
   END
       
QUIT_SP:  

   IF @n_Continue = 3  
   BEGIN  
      IF @@TRANCOUNT > 0  
      BEGIN  
         ROLLBACK TRAN  
      END  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
   
   
   SELECT * from #Temp_LoadSheet11
   WHERE loadkey = @c_Loadkey
   ORDER BY loadkey,Externorderkey,salesman,c_company,sku

   IF OBJECT_ID('tempdb..#Temp_LoadSheet11') IS NOT NULL
      DROP TABLE #Temp_LoadSheet11

   
END -- procedure


GO