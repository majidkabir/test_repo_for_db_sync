SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_SYSSCT01]                          */              
/* Creation Date: 13-Nov-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose: Help to recommend the reasonable carton type                */
/*          for saving courier cost.                                    */
/*                                                                      */
/* Called By: SCEAPI                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes	                                    */
/* 13-Nov-2024    Alex     #PAC-363                                     */
/************************************************************************/ 

CREATE   PROC [API].[isp_ECOMP_SYSSCT01]
   @b_Debug          INT            = 0
,  @c_PickSlipNo     NVARCHAR(10)      
,  @c_OrderKey       NVARCHAR(10)
,  @c_Storerkey      NVARCHAR(15) 
,  @c_Facility       NVARCHAR(5)
,  @b_Success        INT            = 0   OUTPUT  
,  @n_Err            INT            = 0   OUTPUT  
,  @c_ErrMsg         NVARCHAR(255)  = ''  OUTPUT  
,  @c_CTS_Response   NVARCHAR(500)  = ''  OUTPUT
AS  
BEGIN  
   SET NOCOUNT                      ON  
   SET ANSI_NULLS                   OFF  
   SET QUOTED_IDENTIFIER            OFF  
   SET CONCAT_NULL_YIELDS_NULL      OFF  
  
   DECLARE @n_StartTCnt             INT                  = @@TRANCOUNT  
         , @n_Continue              INT                  = 1      

         , @f_TotalCube             FLOAT                = 0
         , @f_MaxSKULength          FLOAT                = 0
         , @f_MaxSKUWidth           FLOAT                = 0
         , @f_MaxSKUHeight          FLOAT                = 0

         , @c_ORDSalesman           NVARCHAR(30)         = ''
         , @c_1stCartonCodeList     NVARCHAR(10)         = ''
         , @c_2ndCartonCodeList     NVARCHAR(10)         = ''

         , @c_1stCartonType         NVARCHAR(10)         = ''
         , @f_1stCartonWeight       FLOAT                = 0
         , @f_1stCubeCalc           FLOAT                = 0
         , @c_2ndCartonType         NVARCHAR(10)         = ''
         , @f_2ndCartonWeight       FLOAT                = 0
         , @f_2ndCubeCalc           FLOAT                = 0

         , @c_CartonType            NVARCHAR(10)         = ''
         , @f_CartonWeight          FLOAT                = 0

   DECLARE @t_CartonTypeList  AS TABLE (
      SeqNo       INT            IDENTITY(1,1),
      CartonType  NVARCHAR(10),
      CubeCalc    FLOAT    
   )

   SET @n_Err                       = 0  
   SET @c_ErrMsg                    = ''  
   SET @c_CTS_Response              = '[]'

   SELECT @f_TotalCube     = SUM(OD.OpenQty * ISNULL(S.STDCUBE, 0))
        --, @f_MaxSKULength  = MAX(S.[Length])
        --, @f_MaxSKUWidth   = MAX(S.[Width])
        --, @f_MaxSKUHeight  = MAX(S.[Height])
   FROM [dbo].[OrderDetail] OD WITH (NOLOCK) 
   JOIN [dbo].[SKU] S WITH (NOLOCK) 
   ON (OD.StorerKey = S.StorerKey AND OD.SKU = S.SKU)
   WHERE OD.OrderKey = @c_OrderKey

   SELECT @f_MaxSKULength  = ISNULL(MAX(S.[Length]), 0)
        , @f_MaxSKUWidth   = ISNULL(MAX(S.[Width]), 0)
        , @f_MaxSKUHeight  = ISNULL(MAX(S.[Height]), 0)
   FROM [dbo].[SKU] S WITH (NOLOCK) 
   WHERE EXISTS ( SELECT 1 FROM [dbo].[OrderDetail] OD WITH (NOLOCK)
      WHERE OD.OrderKey = @c_OrderKey AND OD.StorerKey = S.StorerKey AND OD.SKU = S.SKU )
   AND S.Class IN ('FTW', 'POP')

   SELECT @c_ORDSalesman = ISNULL(RTRIM(Salesman), '')
   FROM [dbo].[ORDERS] WITH (NOLOCK) 
   WHERE OrderKey = @c_OrderKey

   SELECT @c_1stCartonCodeList  = ISNULL(RTRIM([Short]), '')
         ,@c_2ndCartonCodeList = ISNULL(RTRIM([Long]), '')
   FROM [dbo].[Codelkup] WITH (NOLOCK) 
   WHERE ListName = 'VFCTNCFG'
   AND Code = @c_ORDSalesman
   AND StorerKey = @c_Storerkey

   IF @b_Debug = 1 
   BEGIN
      PRINT '@c_ORDSalesman = ' + @c_ORDSalesman
      PRINT '@c_1stCodelkupListName = ' + @c_1stCartonCodeList
      PRINT '@c_2ndCodelkupListName = ' + @c_2ndCartonCodeList
      PRINT '@f_TotalCube = ' + CONVERT(NVARCHAR(15), @f_TotalCube)
      PRINT '@f_MaxSKULength = ' + CONVERT(NVARCHAR(15),@f_MaxSKULength)
      PRINT '@f_MaxSKUWidth = ' + CONVERT(NVARCHAR(15),@f_MaxSKUWidth)
      PRINT '@f_MaxSKUHeight = ' + CONVERT(NVARCHAR(15),@f_MaxSKUHeight)
   END

   IF @c_1stCartonCodeList = '' AND @c_2ndCartonCodeList = ''
   BEGIN
      GOTO QUIT_SP
   END


   --Search for Recommended Carton Type
   --1st Codelkup Listname
   SELECT TOP 1 
      @c_CartonType = CTN.CartonType,
      @f_CartonWeight = CTN.CartonWeight
   FROM [dbo].[Cartonization] CTN WITH (NOLOCK) 
   INNER JOIN [dbo].[Codelkup] CDLK WITH (NOLOCK) 
   ON ( CDLK.ListName = @c_1stCartonCodeList AND CDLK.StorerKey = @c_Storerkey AND CDLK.[Short] = 1 AND CTN.CartonType = CDLK.Code )
   WHERE CTN.[Cube] * (IIF(ISNUMERIC(CDLK.Long) = 1, CDLK.Long, 0)) >= @f_TotalCube
   AND CTN.CartonLength >= @f_MaxSKULength
   AND CTN.CartonWidth >= @f_MaxSKUWidth
   AND CTN.CartonHeight >= @f_MaxSKUHeight
   ORDER BY CTN.[Cube]

   IF @@ROWCOUNT = 0
   BEGIN
       --2nd Codelkup Listname
      SELECT TOP 1 
         @c_CartonType = CTN.CartonType,
         @f_CartonWeight = CTN.CartonWeight
      FROM [dbo].[Cartonization] CTN WITH (NOLOCK) 
      INNER JOIN [dbo].[Codelkup] CDLK WITH (NOLOCK) 
      ON ( CDLK.ListName = @c_2ndCartonCodeList AND CDLK.StorerKey = @c_Storerkey AND CDLK.[Short] = 1 AND CTN.CartonType = CDLK.Code )
      WHERE CTN.[Cube] * (IIF(ISNUMERIC(CDLK.Long) = 1, CDLK.Long, 0)) >= @f_TotalCube
      AND CTN.CartonLength >= @f_MaxSKULength
      AND CTN.CartonWidth >= @f_MaxSKUWidth
      AND CTN.CartonHeight >= @f_MaxSKUHeight
      ORDER BY CTN.[Cube]
   END

   IF ISNULL(@c_CartonType, '') <> ''
   BEGIN
      SET @c_CTS_Response = ISNULL(( 
                              SELECT @c_CartonType       As 'CartonType'
                                    ,@f_CartonWeight     As 'CartonWeight'
                              FOR JSON PATH
                            ), '')
   END

QUIT_SP:  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOMP_SYSSCT01'  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure  
GO