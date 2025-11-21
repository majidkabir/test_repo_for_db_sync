SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_loadmani_mbol06                                */  
/* Creation Date: 2020-02-06                                            */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-11896 - SG - PMI - Load Manifest                        */  
/*                                                                      */  
/* Input Parameters: @c_mbolkey  - mbolkey                              */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:  Used for report dw = r_dw_load_manifest_mbol06               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/*2020-03-17    WLChooi   1.1   Sort by C_Company (WL01)                */
/*2020-05-13    WLChooi   1.2   WMS-13321 - Add SumQtyPerOrder (WL02)   */
/************************************************************************/  
CREATE PROC [dbo].[isp_loadmani_mbol06] (  
     @c_MBOLKey   NVARCHAR(10)  
)  
 AS  
BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
  
    DECLARE @n_continue       INT
         ,  @c_errmsg         NVARCHAR(255)   
         ,  @b_success        INT   
         ,  @n_err            INT   
         ,  @n_StartTCnt      INT   
         ,  @n_count          INT
         ,  @c_CheckConso     NVARCHAR(1)
  
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_continue = 1
  
   WHILE @@TRANCOUNT > 0   
   BEGIN  
      COMMIT TRAN  
   END  

   --Check Discrete/Conso
   SELECT @n_count = COUNT(1)
   FROM MBOL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.MBOLKEY = MBOL.MBOLKEY
   JOIN PACKHEADER (NOLOCK) ON PACKHEADER.ORDERKEY = ORDERS.ORDERKEY
   JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.Pickslipno = PACKHEADER.Pickslipno
   WHERE MBOL.MBOLKEY = @c_MBOLKey
   
   IF @n_count > 0 SET @c_CheckConso = 'N'
   ELSE SET @c_CheckConso = 'Y'

   --WL02 START
   CREATE TABLE #TEMP_DATA (
      Orderkey   NVARCHAR(10),
      Qty        INT )

   IF @c_CheckConso = 'N'
   BEGIN
      INSERT INTO #TEMP_DATA
      SELECT OH.Orderkey, SUM(PD.Qty) AS Qty
      FROM MBOL MB (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.MBOLKEY = MB.MBOLKEY
      JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      WHERE MB.MBOLKey = @c_MBOLKey
      GROUP BY OH.OrderKey
   END
   ELSE
   BEGIN
      INSERT INTO #TEMP_DATA
      SELECT OH.Orderkey, SUM(PD.Qty) AS Qty
      FROM MBOL MB (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.MBOLKEY = MB.MBOLKEY
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      JOIN PACKHEADER PH (NOLOCK) ON LPD.Loadkey = PH.Loadkey
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      WHERE MB.MBOLKey = @c_MBOLKey
      GROUP BY OH.OrderKey
   END

   --WL02 END

   IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CheckConso = 'N')
   BEGIN
      SELECT DISTINCT OH.[Route]
           , MBOL.MbolKey
           , MBOL.ArrivalDateFinalDestination
           , OH.Consigneekey
           , OH.C_Company
           , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) AS C_Address1
           , LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) AS C_Address2
           , LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) AS C_Address3
           , LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) AS C_Address4
           , LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) AS C_Zip
           , LTRIM(RTRIM(ISNULL(OH.C_Country,''))) AS C_Country
           , OH.ExternOrderKey
           , COUNT(DISTINCT PD.LabelNo) AS TotalLabelNo
           , PLT.Palletkey
           , temp.Qty --WL02
      FROM ORDERS OH (NOLOCK)
      JOIN MBOL (NOLOCK) ON MBOL.MbolKey = OH.MBOLKey
      JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = OH.Orderkey
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      CROSS APPLY (SELECT TOP 1 Palletkey FROM PALLETDETAIL PLTD (NOLOCK) WHERE PLTD.UserDefine02 = OH.OrderKey) AS PLT
      CROSS APPLY (SELECT SUM(t.Qty) AS Qty FROM #TEMP_DATA t WHERE t.Orderkey = OH.Orderkey ) AS temp   --WL02
      WHERE MBOL.MBOLKEY = @c_MBOLKey
      GROUP BY OH.[Route]
             , MBOL.MbolKey
             , MBOL.ArrivalDateFinalDestination
             , OH.Consigneekey
             , OH.C_Company
             , LTRIM(RTRIM(ISNULL(OH.C_Address1,'')))
             , LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) 
             , LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) 
             , LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) 
             , LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) 
             , LTRIM(RTRIM(ISNULL(OH.C_Country,'')))
             , OH.ExternOrderKey
             , PLT.Palletkey
             , temp.Qty --WL02
      ORDER BY OH.C_Company   --WL01
   END
   ELSE IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CheckConso = 'Y')
   BEGIN
      SELECT DISTINCT OH.[Route]
           , MBOL.MbolKey
           , MBOL.ArrivalDateFinalDestination
           , OH.Consigneekey
           , OH.C_Company
           , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) AS C_Address1
           , LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) AS C_Address2
           , LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) AS C_Address3
           , LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) AS C_Address4
           , LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) AS C_Zip
           , LTRIM(RTRIM(ISNULL(OH.C_Country,''))) AS C_Country
           , OH.ExternOrderKey
           , COUNT(DISTINCT PD.LabelNo) AS TotalLabelNo
           , PLT.Palletkey
           , temp.Qty --WL02
      FROM ORDERS OH (NOLOCK)
      JOIN MBOL (NOLOCK) ON MBOL.MbolKey = OH.MBOLKey
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      JOIN PACKHEADER PH (NOLOCK) ON LPD.Loadkey = PH.Loadkey
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      CROSS APPLY (SELECT TOP 1 Palletkey FROM PALLETDETAIL PLTD (NOLOCK) WHERE PLTD.UserDefine02 = OH.OrderKey) AS PLT
      CROSS APPLY (SELECT SUM(t.Qty) AS Qty FROM #TEMP_DATA t WHERE t.Orderkey = OH.Orderkey ) AS temp   --WL02
      WHERE MBOL.MBOLKEY = @c_MBOLKey
      GROUP BY OH.[Route]
             , MBOL.MbolKey
             , MBOL.ArrivalDateFinalDestination
             , OH.Consigneekey
             , OH.C_Company
             , LTRIM(RTRIM(ISNULL(OH.C_Address1,'')))
             , LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) 
             , LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) 
             , LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) 
             , LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) 
             , LTRIM(RTRIM(ISNULL(OH.C_Country,'')))
             , OH.ExternOrderKey
             , PLT.Palletkey
             , temp.Qty --WL02
      ORDER BY OH.C_Company   --WL01
   END

   --WL02 START
   IF OBJECT_ID('tempdb..#TEMP_DATA') IS NOT NULL
      DROP TABLE #TEMP_DATA
   --WL02 END

   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN   
   END  
  
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_StartTCnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_loadmani_mbol06'    
      --RAISERROR @n_err @c_errmsg   
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
   END  
  
END  

GO