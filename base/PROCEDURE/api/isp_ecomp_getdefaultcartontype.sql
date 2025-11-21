SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: [API].[isp_ECOMP_GetDefaultCartonType]                      */  
/* Creation Date: 27-APR-2016                                           */  
/* Copyright: Maersk                                                    */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#361901 - New ECOM Packing                               */  
/*        :                                                             */  
/* Called By: nep_n_cst_packinfo_ecom                                   */  
/*          : of_getdefaultcartontype                                   */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 01-JUN-2017 Wan01    1.1   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING   */  
/* 23-May-2018 NJOW01   1.2   WMS-5270 Fix. if cartontype is provided   */  
/*                            and empty cartongroup search cartongroup  */  
/*                            based on cartontype.                      */
/* 05-MAY-2023 Alex     2.0   Clone from WMS EXCEED                     */
/************************************************************************/  
CREATE   PROC [API].[isp_ECOMP_GetDefaultCartonType]   
         @c_Facility    NVARCHAR(5)  
      ,  @c_PickSlipNo  NVARCHAR(10)   
      ,  @n_CartonNo    INT  
      ,  @c_DefaultCartonType  NVARCHAR(10) = '' OUTPUT  
      ,  @c_DefaultCartonGroup NVARCHAR(10) = '' OUTPUT  --(Wan01)   
      ,  @b_AutoCloseCarton    INT = 0           OUTPUT  --(Wan01)   
      ,  @c_Storerkey   NVARCHAR(15) = ''                --(Wan01)        
      ,  @c_Sku         NVARCHAR(20) = ''                --(Wan01)    
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_CartonGroup  NVARCHAR(10)         
         , @b_Success      INT  
         , @n_err          INT               
         , @c_errmsg       NVARCHAR(250)   
  
         --, @c_Storerkey    NVARCHAR(15)  
         , @c_ConfigKey    NVARCHAR(30)  
         , @c_authority    NVARCHAR(30)      
         , @c_Option1      NVARCHAR(50)     
         , @c_Option2      NVARCHAR(50)    
         , @c_Option3      NVARCHAR(50)  
         , @c_Option4      NVARCHAR(50)   
         , @c_Option5      NVARCHAR(4000)  
  
         , @c_Sql          NVARCHAR(4000)  
         , @c_SqlWhere     NVARCHAR(4000)  
         , @c_SqlOrderBy   NVARCHAR(500)  
  
         , @c_CustomSP     NVARCHAR(50)    
               
         , @c_AutocloseCarton NVARCHAR(50)   --(Wan01)  
  
   SET @c_SqlWhere = ''  
           
   IF ISNULL(RTRIM(@c_Storerkey),'') = ''    --(Wan01)  
   BEGIN                                     --(Wan01)  
      SET @c_Storerkey= ''  
      SELECT @c_Storerkey = Storerkey  
      FROM PACKHEADER WITH (NOLOCK)  
      WHERE PickSlipNo = @c_PickSlipNo  
   END                                       --(Wan01)  
  
   SET @c_ConfigKey = 'DefaultCtnType'  
   SET @b_Success = 1  
   SET @n_err     = 0  
   SET @c_errmsg  = ''  
   SET @c_Option1 = ''  
   SET @c_Option2 = ''  
   SET @c_Option3 = ''  
   SET @c_Option4 = ''  
   SET @c_Option5 = ''  
  
   EXEC nspGetRight    
         @c_Facility             
      ,  @c_StorerKey               
      ,  ''         
      ,  @c_ConfigKey               
      ,  @b_Success    OUTPUT     
      ,  @c_authority  OUTPUT    
      ,  @n_err        OUTPUT    
      ,  @c_errmsg     OUTPUT  
      ,  @c_Option1    OUTPUT   
      ,  @c_Option2    OUTPUT -- AutoCloseCarton if default cartongroup and cartontype are from sku  
      ,  @c_Option3    OUTPUT  
      ,  @c_Option4    OUTPUT  
      ,  @c_Option5    OUTPUT  
  
   IF @b_Success <> 1   
   BEGIN   
      GOTO QUIT_SP  
   END  
  
   IF @c_authority <> '1'  
   BEGIN  
      GOTO QUIT_SP  
   END  
     
   --NJOW01 to get carton group  
   IF ISNULL(@c_DefaultCartonType,'') <> '' AND ISNULL(@c_DefaultCartonGroup,'') = ''  
   BEGIN  
      SELECT TOP 1 @c_CartonGroup = S.CartonGroup  
      FROM STORER S (NOLOCK)  
      JOIN CARTONIZATION  CZ WITH (NOLOCK) ON (S.CartonGroup = CZ.CartonizationGroup)        
      WHERE S.Storerkey = @c_Storerkey  
      AND CZ.CartonType = @c_DefaultCartonType  
        
      IF ISNULL(@c_CartonGroup,'') = ''  
      BEGIN  
         SELECT TOP 1 @c_CartonGroup = S.CartonGroup  
         FROM SKU S (NOLOCK)  
         JOIN CARTONIZATION  CZ WITH (NOLOCK) ON (S.CartonGroup = CZ.CartonizationGroup)        
         WHERE S.Storerkey = @c_Storerkey  
         AND S.Sku = @c_Sku  
         AND CZ.CartonType = @c_DefaultCartonType         
         AND S.CartonGroup <> 'STD'    
      END        
        
      IF ISNULL(@c_CartonGroup,'') <> ''   
      BEGIN  
         SET @c_AutocloseCarton = RTRIM(@c_Option2)         
        SET @c_DefaultCartonGroup = @c_CartonGroup  
        GOTO QUIT_SP  
      END  
   END  
     
   SET @c_DefaultCartonType = ''  
   SET @c_DefaultCartonGroup= ''  
   SET @b_AutoCloseCarton   = 0  
  
   SET @c_CustomSP = RTRIM(@c_Option1)  
   SET @c_AutocloseCarton = RTRIM(@c_Option2)  
  
   IF @c_CustomSP <> ''  
   BEGIN  
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = @c_CustomSP AND type = 'P')            
      BEGIN    
         SET @c_SQL = 'EXEC ' + @c_CustomSP       
                    + ' @c_PickSlipNo=@c_PickSlipNo, @n_CartonNo=@n_CartonNo'  
                    + ',@c_DefaultCartonType=@c_DefaultCartonType OUTPUT'  --(Wan01)  
                    + ',@c_DefaultCartonGroup=@c_DefaultCartonGroup OUTPUT'--(Wan01)  
                    + ',@b_AutoCloseCarton=@b_AutoCloseCarton OUTPUT'      --(Wan01)  
                    + ',@c_Storerkey=@c_Storerkey, @c_Sku=@c_Sku'          --(Wan01)            
  
         EXEC sp_executesql @c_SQL            
               , N'@c_PickSlipNo NVARCHAR(10), @n_CartonNo INT  
                  ,@c_DefaultCartonType NVARCHAR(10) OUTPUT, @c_DefaultCartonGroup NVARCHAR(10) OUTPUT  
                  ,@b_AutoCloseCarton INT OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20)'--(Wan01)  
               ,@c_PickSlipNo   
               ,@n_CartonNo    
               ,@c_DefaultCartonType   OUTPUT  
               ,@c_DefaultCartonGroup  OUTPUT                                                   --(Wan01)  
               ,@b_AutoCloseCarton     OUTPUT                                                   --(Wan01)  
               ,@c_Storerkey                                                                    --(Wan01)   
               ,@c_Sku                                                                          --(Wan01)  
  
         IF @c_AutocloseCarton <> '1'  
         BEGIN  
            SET @b_AutoCloseCarton = 0  
         END   
                   
         GOTO QUIT_SP                     
      END    
   END  
  
   SET @c_CartonGroup= ''  
   SELECT @c_CartonGroup = RTRIM(CartonGroup)  
   FROM STORER WITH (NOLOCK)  
   WHERE Storerkey = @c_Storerkey  
  
   SET @c_SqlWhere  = @c_Option5  
  
   SET @c_Sql = N'SELECT TOP 1 @c_DefaultCartonType = CartonType'  
            + ' FROM CARTONIZATION WITH (NOLOCK)'  
            + ' WHERE CartonizationGroup = N''' + RTRIM(@c_CartonGroup) + ''' '  
            + @c_SqlWhere  
            + ' ORDER BY UseSequence'  
  
   EXEC sp_ExecuteSql @c_Sql  
                     ,N'@c_DefaultCartonType NVARCHAR(10) OUTPUT'  
                     ,@c_DefaultCartonType OUTPUT  
  
   SET @c_DefaultCartonGroup = @c_CartonGroup                --(Wan01)   
   QUIT_SP:  
END -- procedure  
GO