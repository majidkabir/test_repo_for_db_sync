SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_LoadSheet10                                         */  
/* Creation Date: 10-Mar-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-12333 - ID-FBR_Loading Sheet Consolidation              */  
/*        :                                                             */  
/* Called By: r_dw_loadsheet10                                          */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_LoadSheet10] 
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
         LPD.LoadKey,
         '' AS Orderkey,
         OH.Facility,
         '' AS Externorderkey,
         OH.Storerkey, 
         CONVERT(NVARCHAR(10),LoadPlan.AddDate, 103) AS AddDate,
         ISNULL(Loadplan.BookingNo,'') AS BookingNo,
         LTRIM(RTRIM(ISNULL(Loadplan.Truck_Type,''))) + ' ,' + LTRIM(RTRIM(ISNULL(Loadplan.Driver,''))) + ' ,' + 
         LTRIM(RTRIM(ISNULL(Loadplan.Vehicle_Type,''))) AS TruckInfo,
         ISNULL(Loadplan.Load_Userdef1,'') as Notes,
         OH.ConsigneeKey,
         OH.C_Company,
         OH.C_Address1,
         LTRIM(RTRIM(ISNULL(OH.C_City,''))) + ' - ' + LTRIM(RTRIM(ISNULL(OH.C_State,''))) AS CityState,
         CASE WHEN PAC.CaseCnt > 0 THEN SUM(PD.qty) % CAST(PAC.CaseCnt AS INT) ELSE SUM(PD.qty) END as PQty,
         CASE WHEN PAC.CaseCnt > 0 THEN FLOOR(SUM(PD.qty) / PAC.CaseCnt) ELSE 0 END as PQtyInCS,
         PD.SKU,
         SKU.Descr,
         CASE WHEN PAC.CaseCnt > 0 THEN FLOOR(PAC.Pallet / PAC.CaseCnt) ELSE 0 END AS Pallet,
         PAC.CaseCnt,
         LOADPLAN.UserDefine01,
         ISNULL(PD.dropid,'') AS Dropid,
         CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN LOTT.Lottable02 ELSE '' END AS Lottable02,
         CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN LOTT.Lottable04 ELSE NULL END AS Lottable04,
         CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN 'Y' ELSE 'N' END AS Showlot24,
         SUSER_SNAME() AS AddWho
      INTO #Temp_LoadSheet10
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
      LEFT JOIN Codelkup CLR (NOLOCK) ON (OH.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWLOT24' 
                                      AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_loadsheet10' AND ISNULL(CLR.Short,'') <> 'N')
      WHERE LPD.LoadKey = @c_Loadkey
      GROUP BY LPD.LoadKey,
         OH.Facility,
         OH.Storerkey, 
         CONVERT(NVARCHAR(10),LoadPlan.AddDate, 103),
         ISNULL(Loadplan.BookingNo,''),
         LTRIM(RTRIM(ISNULL(Loadplan.Truck_Type,''))) + ' ,' + LTRIM(RTRIM(ISNULL(Loadplan.Driver,''))) + ' ,' + 
         LTRIM(RTRIM(ISNULL(Loadplan.Vehicle_Type,''))),
         ISNULL(Loadplan.Load_Userdef1,''),
         OH.ConsigneeKey,
         OH.C_Company,
         OH.C_Address1,
         LTRIM(RTRIM(ISNULL(OH.C_City,''))) + ' - ' + LTRIM(RTRIM(ISNULL(OH.C_State,''))),
         PD.SKU,
         SKU.Descr,
         CASE WHEN PAC.CaseCnt > 0 THEN FLOOR(PAC.Pallet / PAC.CaseCnt) ELSE 0 END,
         PAC.CaseCnt,
         LOADPLAN.UserDefine01,
         ISNULL(PD.dropid,'') ,
         CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN LOTT.Lottable02 ELSE '' END,
         CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN LOTT.Lottable04 ELSE NULL END,
         CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN 'Y' ELSE 'N' END 
      ORDER BY OH.ConsigneeKey,
               ISNULL(PD.dropid,''), PD.Sku
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

   /*SELECT LoadKey,
          '' AS Orderkey,
          Facility,
          '' AS Externorderkey,
          Storerkey, 
          AddDate,
          BookingNo,
          TruckInfo,
          Notes,
          ConsigneeKey,
          C_Company,
          C_Address1,
          CityState,
          PQty,
          SUM(PQtyInCS) AS PQtyInCS,
          SKU,
          Descr,
          Pallet,
          CaseCnt,
          userDefine01,
          Dropid,
          Lottable02,
          Lottable04,
          Showlot24,
          AddWho
   FROM #Temp_LoadSheet10
   GROUP BY LoadKey,
            Facility,
            Storerkey, 
            AddDate,
            BookingNo,
            TruckInfo,
            Notes,
            ConsigneeKey,
            C_Company,
            C_Address1,
            CityState,
            PQty,
            SKU,
            Descr,
            Pallet,
            CaseCnt,
            userDefine01,
            Dropid,
            Lottable02,
            Lottable04,
            Showlot24,
            AddWho
   ORDER BY ConsigneeKey, ISNULL(dropid,''), SKU*/

   SELECT * FROM  #Temp_LoadSheet10 ORDER BY ConsigneeKey, ISNULL(dropid,''), SKU

   IF OBJECT_ID('tempdb..#Temp_LoadSheet10') IS NOT NULL
      DROP TABLE #Temp_LoadSheet10

   
END -- procedure


GO