SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/******************************************************************************/                
/* Store Procedure: isp_Packing_List_63                                       */                
/* Creation Date: 04-APR-2019                                                 */                
/* Copyright: LFL                                                             */                
/* Written by: WLCHOOI                                                        */                
/*                                                                            */                
/* Purpose: WMS-8569 - CN_Trinity_Exceed_Packlist                             */    
/*                                                                            */                
/*                                                                            */                
/* Called By:  r_dw_packing_list_63                                           */                
/*                                                                            */                
/* PVCS Version: 1.2                                                          */                
/*                                                                            */                
/* Version: 1.0                                                               */                
/*                                                                            */                
/* Data Modifications:                                                        */                
/*                                                                            */                
/* Updates:                                                                   */                
/* Date         Author    Ver.  Purposes                                      */    
/* 30/05/2019   WLChooi   1.0   Fixed Qty issue (WL01)                        */  
/* 29/01/2021   WLChooi   1.1   WMS-16227 - Add Remark (WL02)                 */
/* 30-Mar-2023  WLChooi   1.2   WMS-22118 - Add ShowMCompany config (WL03)    */
/* 30-Mar-2023  WLChooi   1.2   DevOps Combine Script                         */
/******************************************************************************/       
    
CREATE   PROC [dbo].[isp_Packing_List_63]               
       (@c_Orderkey NVARCHAR(20), @c_Type NVARCHAR(1) = '' )   --WL02                
AS              
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_WARNINGS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @n_continue           INT            = 1
         , @b_debug              INT            = 0
         , @c_IsOrderKey         INT            = 0
         , @c_IsLoadKey          INT            = 0
         , @c_ExecStatements     NVARCHAR(4000) = N''
         , @c_ExecStatements1    NVARCHAR(4000) = N''
         , @c_ExecStatements2    NVARCHAR(4000) = N''
         , @c_ExecStatementsMain NVARCHAR(4000) = N''
         , @c_ExecArguments      NVARCHAR(4000) = N''
         , @c_GetOrderkey        NVARCHAR(20)   = N''
         --WL02 S
         , @n_MaxRec             INT
         , @n_CurrentRec         INT
         , @n_MaxLineno          INT
         , @c_Storerkey          NVARCHAR(15)
         , @c_CLDescr            NVARCHAR(4000)
   --WL02 E

   CREATE TABLE #PACKLIST63
   (
      Company        NVARCHAR(90)  NULL
    , Contact1       NVARCHAR(50)  NULL
    , [Address]      NVARCHAR(255) NULL
    , Phone1         NVARCHAR(50)  NULL
    , UserDefine02   NVARCHAR(60)  NULL
    , ExternOrderKey NVARCHAR(50)  NULL
    , SKU            NVARCHAR(200) NULL
    , Color          NVARCHAR(40)  NULL
    , Size           NVARCHAR(60)  NULL
    , Descr          NVARCHAR(60)  NULL
    , Qty            INT           NULL
    , Orderkey       NVARCHAR(20)  NULL
    , EditWho        NVARCHAR(80)  NULL
    , ShowRemark     NVARCHAR(10)  NULL --WL02
    , IsDummy        NVARCHAR(10)  NULL --WL02
    , ShowMCompany   NVARCHAR(10)  NULL --WL03
    , M_Company      NVARCHAR(100) NULL --WL03
   )
   
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM ORDERS (NOLOCK)
                   WHERE OrderKey = @c_Orderkey AND LoadKey <> @c_Orderkey) --Orderkey
      BEGIN
         SET @c_IsOrderKey = 1
      END

      IF EXISTS (  SELECT TOP 1 1
                   FROM ORDERS (NOLOCK)
                   WHERE LoadKey = @c_Orderkey AND OrderKey <> @c_Orderkey) --Loadkey
      BEGIN
         SET @c_IsLoadKey = 1
      END

      IF EXISTS (  SELECT TOP 1 1
                   FROM PackHeader (NOLOCK)
                   WHERE PickSlipNo = @c_Orderkey) --Pickslipno
      BEGIN
         SELECT @c_GetOrderkey = PH.OrderKey
         FROM PackHeader PH (NOLOCK)
         WHERE PH.PickSlipNo = @c_Orderkey

         SET @c_Orderkey = @c_GetOrderkey
         SET @c_IsOrderKey = 1
      END
   END    
         
   IF( @n_continue = 1 OR @n_continue = 2 )       
   BEGIN
      --WL03 S
      SET @c_ExecStatements = N' INSERT INTO #PACKLIST63 ( Company, Contact1, [Address], Phone1, UserDefine02, ExternOrderKey ' + CHAR(13)
                            + N'                         , SKU, Color, Size, Descr, Qty, Orderkey, EditWho ' + CHAR(13)
                            + N'                         , ShowRemark, IsDummy, ShowMCompany, M_Company ) '   --WL02 --WL03

      SET @c_ExecStatements = @c_ExecStatements + CHAR(13)
                            + N' SELECT DISTINCT ISNULL(ORD.C_Company,'''') ' + CHAR(13)
                            + N'                , ISNULL(ORD.C_Contact1,'''') ' + CHAR(13)
                            + N'                , LTRIM(RTRIM(ISNULL(ORD.C_city,''''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(ORD.C_state,''''))) + SPACE(1) +  ' + CHAR(13)
                            + N'                  LTRIM(RTRIM(ISNULL(ORD.C_address1,''''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(ORD.C_address2,''''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(ORD.C_address3,''''))) ' + CHAR(13)
                            + N'                , ISNULL(ORD.C_Phone1,'''') ' + CHAR(13)
                            + N'                , ISNULL(ORD.UserDefine02,'''') ' + CHAR(13)
                            + N'                , ORD.ExternOrderKey ' + CHAR(13)
                            + N'                , S.SKU ' + CHAR(13)
                            + N'                , ISNULL(S.Color,'''') ' + CHAR(13)
                            + N'                , ISNULL(S.Size,'''') ' + CHAR(13)
                            + N'                , RTRIM(LTRIM(ISNULL(S.DESCR,''''))) ' + CHAR(13)
                            + N'                , SUM(PIDET.Qty) ' + CHAR(13)   --WL01
                            + N'                , ORD.OrderKey ' + CHAR(13)
                            + N'                , MAX(PIDET.EditWho) ' + CHAR(13)
                            + N'                , ISNULL(CL.Short,''N'') AS ShowRemark ' + CHAR(13)   --WL02
                            + N'                , ''N'' AS IsDummy ' + CHAR(13)   --WL02
                            + N'                , ISNULL(CL1.Short,''N'') AS ShowMCompany ' + CHAR(13)       --WL03
                            + N'                , TRIM(ISNULL(ORD.M_Company,'''')) AS MCompany ' + CHAR(13)  --WL03
                            + N' FROM ORDERS ORD WITH (NOLOCK) ' + CHAR(13)
                            + N' JOIN ORDERDETAIL ORDET WITH (NOLOCK) ON ORD.OrderKey = ORDET.OrderKey ' + CHAR(13)
                            + N' JOIN SKU S WITH (NOLOCK) ON S.StorerKey = ORDET.StorerKey AND S.SKU = ORDET.SKU  ' + CHAR(13)
                            + N' JOIN PICKDETAIL PIDET WITH (NOLOCK) ON ORDET.Orderkey = PIDET.Orderkey ' + CHAR(13)      
                            + N'                                     AND PIDET.OrderLineNumber = ORDET.OrderLineNumber ' + CHAR(13) 
                            + N' LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = ''REPORTCFG'' AND CL.Code = ''ShowRemark'' AND CL.Long = ''r_dw_packing_list_63'' AND CL.Storerkey = ORD.Storerkey ' + CHAR(13)   --WL02
                            + N' LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME = ''REPORTCFG'' AND CL1.Code = ''ShowMCompany'' AND CL1.Long = ''r_dw_packing_list_63'' AND CL1.Storerkey = ORD.Storerkey '   --WL03
      --WL03 E
      IF (@c_IsOrderKey = 1 AND @c_IsLoadKey = 0)
      BEGIN
         SET @c_ExecStatements1 = N'WHERE ORD.ORDERKEY = @c_Orderkey AND ORD.DOCTYPE = ''E'' '
      END
      ELSE IF (@c_IsOrderKey = 0 AND @c_IsLoadKey = 1)
      BEGIN
         SET @c_ExecStatements1 = N'WHERE ORD.LOADKEY = @c_Orderkey AND ORD.DOCTYPE = ''E'' '
      END
      ELSE
         GOTO QUIT_SP

      SET @c_ExecStatements2 = N' GROUP BY ISNULL(ORD.C_Company,'''') ' + CHAR(13)
                             + N'        , ISNULL(ORD.C_Contact1,'''') ' + CHAR(13)
                             + N'        , ISNULL(ORD.C_city,'''') ' + CHAR(13)
                             + N'        , ISNULL(ORD.C_State,'''') ' + CHAR(13)
                             + N'        , ISNULL(ORD.C_Address1,'''') ' + CHAR(13)
                             + N'        , ISNULL(ORD.C_Address2,'''') ' + CHAR(13)
                             + N'        , ISNULL(ORD.C_Address3,'''') ' + CHAR(13)
                             + N'        , ISNULL(ORD.C_Phone1,'''') ' + CHAR(13)
                             + N'        , ISNULL(ORD.UserDefine02,'''') ' + CHAR(13)
                             + N'        , ORD.ExternOrderKey ' + CHAR(13)
                             + N'        , S.Sku ' + CHAR(13)
                             + N'        , ISNULL(S.Color,'''') ' + CHAR(13)
                             + N'        , ISNULL(S.Size,'''') ' + CHAR(13)
                             + N'        , ISNULL(S.DESCR,'''') ' + CHAR(13)
                             + N'        , ORD.OrderKey ' + CHAR(13) 
                             + N'        , ISNULL(CL.Short,''N'') ' + CHAR(13)    --WL02
                             + N'        , ISNULL(CL1.Short,''N'') ' + CHAR(13)   --WL03
                             + N'        , ORD.M_Company ' --WL03

   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SET @c_ExecStatementsMain = @c_ExecStatements + CHAR(13) + @c_ExecStatements1 + CHAR(13) + @c_ExecStatements2

      SET @c_ExecArguments = N'@c_Orderkey NVARCHAR(20)'

      IF (@b_debug = 1)
      BEGIN
         PRINT @c_ExecStatementsMain
      END

      EXEC sp_executesql @c_ExecStatementsMain, @c_ExecArguments, @c_Orderkey
   END
    
      --WL02 S
   IF EXISTS (  SELECT 1
                FROM #PACKLIST63
                WHERE ShowRemark = 'Y')
   BEGIN
      SELECT @c_Storerkey = OH.StorerKey
      FROM ORDERS OH (NOLOCK)
      JOIN #PACKLIST63 T ON T.Orderkey = OH.OrderKey

      SELECT @n_MaxLineno = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT)
                                 ELSE 10 END
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'REPORTCFG'
      AND   CL.Code = 'MaxLineNo'
      AND   CL.Long = 'r_dw_packing_list_63'
      AND   CL.code2 = 'r_dw_packing_list_63'
      AND   CL.Storerkey = @c_Storerkey

      IF ISNULL(@n_MaxLineno, 0) = 0
      BEGIN
         SET @n_MaxLineno = 10
      END

      SELECT @c_CLDescr = ISNULL(CL.[Description], '')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'PACKPrint' AND CL.Storerkey = @c_Storerkey

      SELECT @n_MaxRec = COUNT(1)
      FROM #PACKLIST63

      SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno

      WHILE (@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)
      BEGIN
         INSERT INTO #PACKLIST63
         SELECT TOP 1 Company
                    , Contact1
                    , [Address]
                    , Phone1
                    , UserDefine02
                    , ExternOrderKey
                    , NULL
                    , NULL
                    , NULL
                    , NULL
                    , NULL
                    , Orderkey
                    , EditWho
                    , ShowRemark
                    , 'Y'
                    , ShowMCompany   --WL03
                    , M_Company   --WL03
         FROM #PACKLIST63

         SET @n_CurrentRec = @n_CurrentRec + 1
      END
   END
    
   IF @c_Type = 'F'
   BEGIN
      SELECT TOP 1 Orderkey
                 , ShowRemark
                 , @c_CLDescr
      FROM #PACKLIST63

      GOTO QUIT_SP
   END
   --WL01 E

   SELECT Company
        , Contact1
        , [Address]
        , Phone1
        , UserDefine02
        , ExternOrderKey
        , SKU
        , Color
        , Size
        , Descr
        , Qty
        , Orderkey
        , EditWho
        , ShowRemark --WL02
        , IsDummy --WL02
        , ShowMCompany --WL03
        , M_Company   --WL03
   FROM #PACKLIST63

QUIT_SP:                
END  

GO