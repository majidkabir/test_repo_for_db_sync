SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_UCC_Carton_Label_93                                 */  
/* Creation Date: 06-Mar-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-12357 - [CN] QHW_HEDGREN_PACKING_LABEL                  */  
/*        :                                                             */  
/* Called By: r_dw_UCC_Carton_Label_93                                  */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 24-Apr-2020  WLChooi   1.1 Fix Carton Sorting, and missing SKU if    */
/*                            SKUCount < 7 (WL01)                       */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_UCC_Carton_Label_93]  
            @c_Storerkey         NVARCHAR(15),
            @c_Pickslipno        NVARCHAR(10),
            @c_StartCartonNo     NVARCHAR(10),
            @c_EndCartonNo       NVARCHAR(10),
            @c_Type              NVARCHAR(10) = ''
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
  
         , @c_ExternOrderKey  NVARCHAR(50)  

         , @c_RptLogo             NVARCHAR(255)  
         , @c_ecomflag            NVARCHAR(50)
         , @n_MaxLineno           INT
         , @n_MaxId               INT
         , @n_MaxRec              INT
         , @n_CurrentRec          INT
         , @c_recgroup            INT
         , @n_MaxCartonNo         INT
         , @n_Loop                INT
         , @n_LoopCnt             INT
         , @c_Conso               NVARCHAR(10) = 'N'
         , @c_Orderkey            NVARCHAR(10)
         , @c_GetPickslipno       NVARCHAR(10)
         , @c_GetCartonNo         NVARCHAR(10)
         , @n_CountSKU            INT = 0
         , @n_MaxLineFirstPage    INT = 7
         , @n_MaxLineRemainPage   INT = 11
         , @n_CurrentPage         INT
         , @n_TotalPage           INT
         , @c_TotalRows           INT
         , @n_PageGroup           INT = 1
         , @n_Max                 INT

  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 
   SET @n_Loop      = 1

   SELECT @n_MaxCartonNo = MAX(CartonNo)
   FROM PACKDETAIL (NOLOCK) 
   WHERE Pickslipno = @c_Pickslipno

   CREATE TABLE #Temp_PACK93 (
        Externorderkey   NVARCHAR(50),
        CartonNo         NVARCHAR(5),
        Notes2           NVARCHAR(255),
        Notes1           NVARCHAR(255),
        SUSR2            NVARCHAR(50),
        SUSR1            NVARCHAR(50),
        ConsigneeKey     NVARCHAR(15),
        DeliveryDate     DATETIME,
        SKU              NVARCHAR(20),
        PACKQty          INT,
        LabelNo          NVARCHAR(20),
        Storerkey        NVARCHAR(15),
        Pickslipno       NVARCHAR(10)
   )

   SELECT @c_Orderkey = Orderkey
   FROM PACKHEADER (NOLOCK)
   WHERE Pickslipno = @c_Pickslipno

   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      SET @c_Conso = 'Y'
   END

   WHILE @n_Loop > 0
   BEGIN
   IF @c_Conso = 'Y'
   BEGIN
      INSERT INTO #Temp_PACK93
      SELECT MAX(OH.ExternOrderkey) AS ExternOrderkey
           , PD.CartonNo
           , ISNULL(St.Notes2,'') AS Notes2
           , ISNULL(St.Notes1,'') AS Notes1
           , ISNULL(St.SUSR2,'') AS SUSR2
           , ISNULL(St.SUSR1,'') AS SUSR1
           , MAX(OH.ConsigneeKey) AS ConsigneeKey
           , MAX(OH.DeliveryDate) AS DeliveryDate
           , PD.SKU
           , SUM(PD.Qty) AS PACKQty
           , PD.LabelNo
           , @c_Storerkey    
           , @c_Pickslipno   
      FROM ORDERS OH (NOLOCK)
      LEFT JOIN STORER St (NOLOCK) ON St.Storerkey = OH.ConsigneeKey
      JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      JOIN PACKHEADER PH (NOLOCK) ON PH.LoadKey = LPD.LoadKey
      JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      WHERE PH.Storerkey = @c_Storerkey
        AND PH.PickSlipNo = @c_Pickslipno
        AND PD.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo
      GROUP BY PD.CartonNo
           , ISNULL(St.Notes2,'')
           , ISNULL(St.Notes1,'')
           , ISNULL(St.SUSR2,'') 
           , ISNULL(St.SUSR1,'') 
           , PD.SKU
           , PD.LabelNo
   END
   ELSE
   BEGIN
      INSERT INTO #Temp_PACK93
      SELECT MAX(OH.ExternOrderkey) AS ExternOrderkey
           , PD.CartonNo
           , ISNULL(St.Notes2,'') AS Notes2
           , ISNULL(St.Notes1,'') AS Notes1
           , ISNULL(St.SUSR2,'') AS SUSR2
           , ISNULL(St.SUSR1,'') AS SUSR1
           , MAX(OH.ConsigneeKey) AS ConsigneeKey
           , MAX(OH.DeliveryDate) AS DeliveryDate
           , PD.SKU
           , SUM(PD.Qty) AS PACKQty
           , PD.LabelNo
           , @c_Storerkey    
           , @c_Pickslipno   
      FROM ORDERS OH (NOLOCK)
      LEFT JOIN STORER St (NOLOCK) ON St.Storerkey = OH.ConsigneeKey
      JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
      JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      WHERE PH.Storerkey = @c_Storerkey
        AND PH.PickSlipNo = @c_Pickslipno
        AND PD.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo
      GROUP BY PD.CartonNo
           , ISNULL(St.Notes2,'')
           , ISNULL(St.Notes1,'')
           , ISNULL(St.SUSR2,'') 
           , ISNULL(St.SUSR1,'') 
           , PD.SKU
           , PD.LabelNo
   END

      SET @n_Loop = @n_Loop - 1
   END

   IF @c_Type = 'MAIN'
   BEGIN
      SELECT Externorderkey
           , CartonNo      
           , Notes2        
           , Notes1        
           , SUSR2         
           , SUSR1         
           , ConsigneeKey  
           , DeliveryDate            
           , LabelNo       
           , Storerkey     
           , Pickslipno  
           , SUM(PACKQty) AS SUMPackQty
           , @n_MaxCartonNo
      FROM #Temp_PACK93
      GROUP BY Externorderkey
             , CartonNo      
             , Notes2        
             , Notes1        
             , SUSR2         
             , SUSR1         
             , ConsigneeKey  
             , DeliveryDate            
             , LabelNo       
             , Storerkey     
             , Pickslipno  
      ORDER BY CAST(CartonNo AS INT)   --WL01
   END
   ELSE IF @c_Type = 'SUB1'
   BEGIN
      SELECT DISTINCT 
             Notes2        
           , Notes1        
           , SUSR2         
           , SUSR1         
           , ConsigneeKey     
      FROM #Temp_PACK93
   END
   ELSE IF @c_Type = 'SUB2'
   BEGIN
      SELECT Pickslipno, CartonNo, SKU, PACKQty
      INTO #Temp_PACKSKU93
      FROM #Temp_PACK93
      WHERE 1=2

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Pickslipno, CartonNo
      FROM #Temp_PACK93

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_GetPickslipno, @c_GetCartonNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         
         SELECT @n_CountSKU = COUNT(1)
         FROM #Temp_PACK93
         WHERE Pickslipno = @c_GetPickslipno AND CartonNo = @c_GetCartonNo

         INSERT INTO #Temp_PACKSKU93
         SELECT @c_GetPickslipno, @c_GetCartonNo, SKU, PACKQty
         FROM #Temp_PACK93

         IF @n_CountSKU < @n_MaxLineFirstPage
         BEGIN
            SET @n_Loop = @n_MaxLineFirstPage - @n_CountSKU -- - 1  --WL01

            WHILE (@n_Loop > 0)
            BEGIN

               INSERT INTO #Temp_PACKSKU93
               SELECT @c_GetPickslipno, @c_GetCartonNo, '', 0

               SET @n_Loop = @n_Loop - 1 
            END
         END
         ELSE
         BEGIN
            SET @n_Loop = @n_MaxLineRemainPage - ((@n_CountSKU - @n_MaxLineFirstPage) % @n_MaxLineRemainPage)
            SET @n_LoopCnt = 1

            WHILE (@n_Loop > 0)
            BEGIN
               INSERT INTO #Temp_PACKSKU93
               SELECT @c_GetPickslipno, @c_GetCartonNo, '', 0

               SET @n_Loop = @n_Loop - 1 
            END
         END

         SELECT @c_TotalRows = COUNT(1)
         FROM #Temp_PACKSKU93

         FETCH NEXT FROM CUR_LOOP INTO @c_GetPickslipno, @c_GetCartonNo
      END

      SELECT TOP (@c_TotalRows - 1)--DISTINCT 
             SKU        
           , PACKQty
           , CASE WHEN ROW_NUMBER() OVER (ORDER BY CASE WHEN SKU = '' THEN 2 ELSE 1 END) > @n_MaxLineFirstPage
                  THEN (Row_Number() OVER (PARTITION BY SKU Order By SKU, PACKQty Asc) - @n_MaxLineFirstPage - 1 ) / @n_MaxLineRemainPage + 2
                  ELSE 1 END AS PageGroup
      INTO #Temp_PACKSKU93_Final
      FROM #Temp_PACKSKU93
      ORDER BY CASE WHEN SKU = '' THEN 2 ELSE 1 END

      SELECT @n_Max = MAX(Pagegroup)
      FROM #Temp_PACKSKU93_Final

      UPDATE #Temp_PACKSKU93_Final
      SET PageGroup = @n_Max
      WHERE SKU = '' AND PACKQty = 0

      SELECT * FROM #Temp_PACKSKU93_Final 
      ORDER BY CASE WHEN SKU = '' THEN 2 ELSE 1 END, PageGroup
      --ORDER BY CASE WHEN SKU = '' THEN 2 ELSE 1 END
   END
   
   IF OBJECT_ID('tempdb..#Temp_PACK93') IS NOT NULL
      DROP TABLE #Temp_PACK93

   IF OBJECT_ID('tempdb..#Temp_PACKSKU93') IS NOT NULL
      DROP TABLE #Temp_PACKSKU93

   IF OBJECT_ID('tempdb..#Temp_PACKSKU93_Final') IS NOT NULL
      DROP TABLE #Temp_PACKSKU93_Final

   IF CURSOR_STATUS('LOCAL' , 'CUR_LOOP') in (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
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
   
END -- procedure


GO