SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Proc: isp_Delivery_Note46_rdt                                 */    
/* Creation Date: 28-Aug-2020                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-14915 - KR ADIDAS_Invoice Report Data Window            */    
/*        :                                                             */    
/* Called By: r_dw_Delivery_Note46_rdt                                  */    
/*          :                                                           */    
/* GitLab Version: 1.2                                                  */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver Purposes                                  */  
/* 09-Dec-2020  CSCHONG   1.1 WMS-15838 - revised contact and zip (CS01)*/ 
/* 08-Dec-2020  WLChooi   1.2 WMS-15838 - Add new column (WL01)         */  
/************************************************************************/    
    
CREATE PROC [dbo].[isp_Delivery_Note46_rdt]    
            @c_Orderkey     NVARCHAR(30)  
  
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
  
   DECLARE    
         @c_Storerkey         NVARCHAR(15) = ''  
       , @c_Long              NVARCHAR(250)  
       , @c_Code              NVARCHAR(30)   
       , @c_Descr             NVARCHAR(250)  
       , @c_Short             NVARCHAR(10)  
       , @c_UDF01             NVARCHAR(60)  
       , @c_UDF02             NVARCHAR(60)  
       , @c_UDF03             NVARCHAR(60)  
       , @c_UDF04             NVARCHAR(60)     
       , @c_Notes             NVARCHAR(4000)   
       , @c_C1                NVARCHAR(250)  
       , @c_C2                NVARCHAR(250)  
       , @c_C3                NVARCHAR(250)  
       , @c_C4                NVARCHAR(250)  
       , @c_C5                NVARCHAR(250)  
       , @c_C6                NVARCHAR(250)  
       , @c_C7                NVARCHAR(250)  
       , @c_C8                NVARCHAR(250)  
       , @c_C9                NVARCHAR(250)  
       , @c_C10               NVARCHAR(250)  
       , @c_C11               NVARCHAR(250)  
       , @c_C12               NVARCHAR(250)  
       , @c_C13               NVARCHAR(250)  
  
   SELECT @c_Storerkey = Storerkey  
   FROM ORDERS (NOLOCK)  
   WHERE Orderkey = @c_Orderkey  
    
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue  = 1    
   SET @b_Success   = 1    
   SET @n_Err       = 0    
   SET @c_Errmsg    = ''   
  
   DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT C.Code, C.Long, C.[Description], C.Short, C.UDF01, C.UDF02, C.UDF03, C.UDF04, C.Notes     
   FROM CODELKUP C WITH (NOLOCK)     
   WHERE C.Listname = 'ADINVCONST' AND C.Storerkey = @c_Storerkey  
   ORDER BY C.code  
    
   OPEN CUR_CODELKUP     
       
   FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Long, @c_Descr, @c_Short, @c_UDF01, @c_UDF02, @c_UDF03, @c_UDF04, @c_Notes      
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      IF @c_Code = 'C01'   
      BEGIN  
        SET @c_C1 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C02'  
      BEGIN  
         SET @c_C2 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C03'  
      BEGIN  
         SET @c_C3 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C04'  
      BEGIN  
         SET @c_C4 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C05'  
      BEGIN  
         SET @c_C5 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C06'  
      BEGIN  
         SET @c_C6 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C07'  
      BEGIN  
         SET @c_C7 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C08'  
      BEGIN  
         SET @c_C8 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C09'  
      BEGIN  
         SET @c_C9 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C10'  
      BEGIN  
         SET @c_C10 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C11'  
      BEGIN  
         SET @c_C11 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C12'  
      BEGIN  
         SET @c_C12 = ISNULL(@c_Long,'')  
      END  
      ELSE IF @c_Code = 'C13'  
      BEGIN  
         SET @c_C13 = ISNULL(@c_Long,'')  
      END  
  
   FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Long, @c_Descr, @c_Short, @c_UDF01, @c_UDF02, @c_UDF03, @c_UDF04, @c_Notes         
            
   END -- While                       
   CLOSE CUR_CODELKUP                      
   DEALLOCATE CUR_CODELKUP  
  
   SELECT CL.Long  
        , OIF.EcomOrderId  
        , substring(OH.C_Contact1,1,LEN(OH.C_Contact1)-1 ) +'*' --OH.C_Contact1           --CS01 
        , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +   
          LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) AS C_Addresses  
        , OH.OrderDate  
        , CONVERT(DATE,getdate(),102) AS TodayDate  
        , '' --OH.C_Zip                --CS01  
        , S.Style  
        , OD.userdefine08  
        , S.[Descr]  
        , SUM(PD.Qty) AS Qty  
        , @c_C1  AS C1   
        , @c_C2  AS C2   
        , @c_C3  AS C3   
        , @c_C4  AS C4   
        , @c_C5  AS C5   
        , @c_C6  AS C6   
        , @c_C7  AS C7   
        , @c_C8  AS C8   
        , @c_C9  AS C9   
        , @c_C10 AS C10  
        , @c_C11 AS C11  
        , @c_C12 AS C12  
        , @c_C13 AS C13  
        , OH.ExternOrderKey   --WL01  
        , OH.OrderKey         --WL01  
        , S.SKU               --WL01  
        , S.MANUFACTURERSKU   --WL01   
   FROM ORDERS OH (NOLOCK)  
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.Orderkey = OD.Orderkey  
   JOIN PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber  
                              AND OD.SKU = PD.SKU  
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = PD.StorerKey  
   LEFT JOIN OrderInfo OIF WITH (NOLOCK) ON OIF.Orderkey = OH.Orderkey  
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'ADBRAND' AND CL.code = OIF.[Platform]  
                                      AND CL.Storerkey = OH.StorerKey  
   WHERE OH.Orderkey = @c_Orderkey  
   GROUP BY CL.Long  
          , OIF.EcomOrderId  
          , OH.C_Contact1  
          , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,'')))  
          , OH.OrderDate  
          --, OH.C_Zip        --CS01
          , S.Style  
          , OD.userdefine08  
          , S.[Descr]  
          , OH.ExternOrderKey   --WL01  
          , OH.OrderKey         --WL01  
          , S.SKU               --WL01  
          , S.MANUFACTURERSKU   --WL01   
  
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