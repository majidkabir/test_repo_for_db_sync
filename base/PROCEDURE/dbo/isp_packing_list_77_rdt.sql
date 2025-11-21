SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Packing_List_77_rdt                                 */  
/* Creation Date: 28-May-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-13325 - [JP] Desigual - B2B Packing List - NEW          */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_77_rdt                                  */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 2020-08-04   WLChooi   1.1 WMS-14575 - Modify column (WL01)          */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Packing_List_77_rdt]  
            @c_Storerkey     NVARCHAR(10)
           ,@c_Pickslipno    NVARCHAR(20)
           ,@c_cartonno      NVARCHAR(5)
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

         , @c_RptLogo         NVARCHAR(255)  
         , @c_ecomflag        NVARCHAR(50)
         , @n_MaxLineno       INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_CurrentRec      INT
         , @c_recgroup        INT

DECLARE  @c_A2                 NVARCHAR(100)
        ,@c_A3_1               NVARCHAR(200)
        ,@c_A3_2               NVARCHAR(200)
        ,@c_A3_3               NVARCHAR(200)
        ,@c_A3_4               NVARCHAR(200)
        ,@c_A3_5               NVARCHAR(200)
        ,@c_A3_6               NVARCHAR(200)
        ,@c_A5_1               NVARCHAR(200)
        ,@c_A5_2               NVARCHAR(200)
        ,@c_A5_3               NVARCHAR(200)
        ,@c_A5_4               NVARCHAR(200)
        ,@c_A5_5               NVARCHAR(200)
        ,@c_A6                 NVARCHAR(200)
        ,@c_A7                 NVARCHAR(200)
        ,@c_A8                 NVARCHAR(200)
        ,@c_A13                NVARCHAR(200) 
        ,@c_A15                NVARCHAR(100) 
        ,@c_A16                NVARCHAR(100) 
        ,@c_A17                NVARCHAR(200) 
        ,@c_A18                NVARCHAR(200) 
        ,@c_A19                NVARCHAR(200) 
        ,@c_A20                NVARCHAR(200) 
        ,@c_A21                NVARCHAR(200) 
        ,@c_A29                NVARCHAR(200)
        ,@c_A31                NVARCHAR(200) 
        ,@c_long               NVARCHAR(250)
        ,@c_code               NVARCHAR(30) 
        ,@c_descr              NVARCHAR(250)
        ,@c_short              NVARCHAR(10)
        ,@c_udf01              NVARCHAR(60)
        ,@c_udf02              NVARCHAR(60)
        ,@c_udf03              NVARCHAR(60)
        ,@c_udf04              NVARCHAR(60)   
        ,@c_notes              NVARCHAR(4000) 
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 


   DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT c.code,c.long,c.description,c.short,c.udf01,c.udf02,c.udf03,c.udf04,c.notes   
   FROM   CODELKUP C WITH (NOLOCK)   
   WHERE C.listname = 'DSB2BPKLST' 
   ORDER BY C.code
  
   OPEN CUR_CODELKUP   
     
   FETCH NEXT FROM CUR_CODELKUP INTO @c_code,@c_long,@c_descr,@c_short,@c_udf01,@c_udf02,@c_udf03,@c_udf04,@c_notes    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  

   IF @c_code = 'A2' 
   BEGIN
     SET @c_a2 = ISNULL(@c_long,'')
   END
   ELSE IF @c_code = 'A3'
   BEGIN
      SET @c_A3_1 = ISNULL(@c_long,'')
      SET @c_A3_2 = ISNULL(@c_descr,'')
      SET @c_A3_3 = ISNULL(@c_short,'')
      SET @c_A3_4 = ISNULL(@c_udf01,'')
      SET @c_A3_5 = ISNULL(@c_udf02,'')
      SET @c_A3_6 = ISNULL(@c_udf03,'') 

   END
   ELSE IF @c_code = 'A5'
   BEGIN
       
       SET @c_A5_1 = ISNULL(@c_long,'')
       SET @c_A5_2 = ISNULL(@c_udf01,'')
       SET @c_A5_3 = ISNULL(@c_udf02,'')
       SET @c_A5_4 = ISNULL(@c_udf03,'')
       SET @c_A5_5 = ISNULL(@c_udf04,'')
   END
   ELSE IF @c_code = 'A6' 
   BEGIN
     SET @c_A6 = ISNULL(@c_long,'')
   END 
   ELSE IF @c_code = 'A7' 
   BEGIN
     SET @c_A7 = ISNULL(@c_long,'')
   END
   ELSE IF @c_code = 'A8' 
   BEGIN
     SET @c_A8 = ISNULL(@c_long,'')
   END
   ELSE IF @c_code = 'A13' 
   BEGIN
     SET @c_A13 = ISNULL(@c_long,'')
   END
   ELSE IF @c_code = 'A15' 
   BEGIN
     SET @c_A15 = ISNULL(@c_long,'')
   END
   ELSE IF @c_code = 'A16' 
   BEGIN
     SET @c_A16 = ISNULL(@c_long,'')
   END
   ELSE IF @c_code = 'A17' 
   BEGIN
     SET @c_A17 = ISNULL(@c_long,'')
   END
   ELSE IF @c_code = 'A18' 
   BEGIN
     SET @c_A18 = ISNULL(@c_long,'')
   END
   ELSE IF @c_code = 'A19' 
   BEGIN
     SET @c_A19 = ISNULL(@c_long,'')
   END
   ELSE IF @c_code = 'A20' 
   BEGIN
     SET @c_A20 = ISNULL(@c_long,'')
   END 
   ELSE IF @c_code = 'A21' 
   BEGIN
     SET @c_A21 = ISNULL(@c_long,'')
   END
    ELSE IF @c_code = 'A29' 
   BEGIN
     SET @c_A29 = ISNULL(@c_long,'')
   END
    ELSE IF @c_code = 'A31' 
   BEGIN
     SET @c_A31 = ISNULL(@c_notes,'')
   END

   FETCH NEXT FROM CUR_CODELKUP INTO @c_code,@c_long,@c_descr,@c_short,@c_udf01,@c_udf02,@c_udf03,@c_udf04,@c_notes      
          
   END -- While                     
   CLOSE CUR_CODELKUP                    
   DEALLOCATE CUR_CODELKUP

   SELECT DISTINCT OH.B_contact1 as B_Contact
        , OH.ExternOrderkey as ExternOrderkey
        , OH.C_contact1 as C_Contact1
        , OH.C_State as C_State
        , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) 
          + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) AS C_Addresses
        , LTRIM(RTRIM(ISNULL(OH.C_Phone1,''))) AS C_Phone1
        , ISNULL(OH.C_City,'') AS c_city
        , ISNULL(OH.C_Country,'') AS C_Country
        , LEFT(OH.C_Zip,3)+'ー'+RIGHT(OH.C_Zip,4) AS C_Zip
        , PH.PickSlipNo AS Pickslipno
        , S.MANUFACTURERSKU AS MSKU
        , PIF.CartonNo as CartonNo
        , ISNULL(OH.BuyerPO,'') AS BuyerPO
        --, ISNULL(PIF.refno,'') AS PRefno  --40   --WL01
        , ISNULL(PD.LabelNo,'') AS PRefno   --WL01
        , (PD.Qty) AS Qty
        , ISNULL(c.description,'') AS BoxDescr     
        , ISNULL(S.Style,'') AS SStyle
        , ISNULL(S.Color,'') AS SColor
        , ISNULL(S.Size,'') AS SSize
        , ISNULL(S.Descr,'') AS SDESCR
        , @c_A2 as A2
        , @c_A3_1 as A3_1
        , @c_A3_2 as A3_2
        , @c_A3_3 as A3_3
        , @c_A3_4 as A3_4
        , @c_A3_5 as A3_5
        , @c_A3_6 as A3_6
        , @c_A5_1 as A5_1
        , @c_A5_2 as A5_2
        , @c_A5_3 as A5_3
        , @c_A5_4 as A5_4
        , @c_A5_5 as A5_5
        , @c_A6 as A6
        , @c_A7 as A7
        , @c_A8 as A8
        , @c_A13 as A13
        , @c_A15 as A15
        , @c_A16 as A16
        , @c_A17 as A17
        , @c_A18 as A18 
        , @c_A19 as A19 
        , @c_A20 as A20
        , @c_A21 as A21
        , @c_A29 as A29
        , @c_A31 as A31
        , PD.labelno as Labelno
   FROM ORDERS OH (NOLOCK)
   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   JOIN SKU S WITH (NOLOCK) ON S.sku = PD.sku AND S.StorerKey = PD.StorerKey
   JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo 
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'DSCARTON' AND C.code = PIF.CartonType AND C.Storerkey = OH.StorerKey
   WHERE PH.PickSlipNo = @c_Pickslipno
   AND PD.CartonNo = CAST(@c_cartonno AS INT)
   AND PH.StorerKey = @c_Storerkey
   

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