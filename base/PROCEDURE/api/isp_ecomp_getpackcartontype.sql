SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Trigger: [API].[isp_ECOMP_GetPackCartonType]                         */      
/* Creation Date: 27-APR-2016                                           */      
/* Copyright: Maersk                                                    */      
/* Written by: YTWan                                                    */      
/*                                                                      */      
/* Purpose: SOS#361901 - New ECOM Packing                               */      
/*        :                                                             */      
/* Called By:  d_dw_ecom_packcartontype                                 */      
/*          :                                                           */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 7.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Author   Ver   Purposes                                  */      
/* 01-JUN-2017 Wan01    1.1   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING   */      
/* 24-APR-2017 Wan02    1.2   WMS-4628 - [CR] DYSON - ECOM Packing      */       
/* 02-JAN-2019 WLCHOOI  1.3   WMS-7418 - CN IKEA Ecom Packing CR (WL01) */     
/* 09-DEC-2020 Wan03    1.4   WMS-15844 - CR CN IKEA ECOM Packing Module*/    
/*                            Enhancement on Carton List Shown By       */    
/*                            StorerkeyFacilityCartonization            */    
/* 14-DEC-2020 Wan04    1.4   WMS-15244-[CN] NIKE_O2_Ecom_packing_RFID_CR*/   
/* 16-FEB-2023 Wan05    1.5   PAC-4 NextGen Ecom Packing - Single       */  
/* 05-MAY-2023 Alex     2.0   Clone from EXCEED WMS                     */
/* 27-JUL-2024 Alex01   2.1   PAC-347 Extend to display 30 carton type  */
/* 07-Aug-2024 Alex02   2.2   #JIRA PAC-352 Bug fixes                   */
/************************************************************************/      
CREATE   PROC [API].[isp_ECOMP_GetPackCartonType]      
   @c_Facility    NVARCHAR(5)      
,  @c_Storerkey   NVARCHAR(15)      
,  @c_CartonType  NVARCHAR(10) = ''       
,  @c_CartonGroup NVARCHAR(10) = ''    --(Wan01)      
,  @c_PickSlipNo  NVARCHAR(10) = ''    --(Wan02)      
,  @n_CartonNo    INT          = 0     --(Wan02)   
,  @c_SourceApp   NVARCHAR(10) = 'WMS' --Wan05, IF SCE, return result set may impact NextGen Ecom   
AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE       
--           @c_CartonGroup  NVARCHAR(10) --(Wan01)      
           @n_StartTCnt       INT            --(Wan01)      
         , @b_Success         INT      
         , @n_err             INT                   
         , @c_errmsg          NVARCHAR(250)       
      
         , @c_ConfigKey       NVARCHAR(30)      
         , @c_authority       NVARCHAR(30)          
         , @c_Option1         NVARCHAR(50)         
         , @c_Option2         NVARCHAR(50)        
         , @c_Option3         NVARCHAR(50)      
         , @c_Option4         NVARCHAR(50)       
         , @c_Option5         NVARCHAR(4000)      
      
         , @c_Sql             NVARCHAR(4000)     
         , @c_SQLParms        NVARCHAR(4000) --(Wan03)     
         , @c_SqlWhere        NVARCHAR(4000)      
      
         , @c_SPCode          NVARCHAR(100)  --(Wan02)    
         , @c_CartonGroupALT  NVARCHAR(10)   = '' --(Wan04)      
         , @c_AlertMsg        NVARCHAR(255)  = '' --(Wan04)      
      
   --(Wan01) - START      
   SET @n_StartTCnt = @@TRANCOUNT      
      
   --WHILE @@TRANCOUNT > 0 AND @c_SourceApp = 'WMS'        --(Wan05)    
   --BEGIN          
   --   COMMIT TRAN      
   --END      
   --SET @c_CartonGroup= ''      
   --(Wan01) - END                        
   SET @c_SqlWhere = ''      
        
   IF ISNULL(RTRIM(@c_ConfigKey),'') = '' BEGIN SET @c_ConfigKey  =  'CtnTypeInput' END      
   SET @c_CartonType = ISNULL(RTRIM(@c_CartonType),'')      
      
   SET @c_ConfigKey = 'CtnTypeInput'      
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
      ,  @c_Option2    OUTPUT      
      ,  @c_Option3    OUTPUT      
      ,  @c_Option4    OUTPUT      
      ,  @c_Option5    OUTPUT      
      
   IF @b_Success <> 1       
   BEGIN       
      GOTO QUIT_SP      
   END      
      
   --(Wan03) - START    
   IF @c_authority = '1'                       
   BEGIN     
      IF ISNULL(@c_Option1,'') <> ''     
      BEGIN    
         SET @c_CartonGroup = @c_Option1    
      END    
      ELSE    
      BEGIN     
         -- Get Sku CartonGroup and Validate Input CartonType at Custom SP     
         IF ISNULL(@c_Option2,'') NOT IN ( '0', '1', '' ) -- Sku CartonGroup For Single    
         BEGIN    
            IF EXISTS ( SELECT 1 FROM sys.objects AS o WHERE NAME = @c_Option2 AND o.[type] = 'P')    
            BEGIN    
               SET @c_SQL  = 'EXEC ' + RTRIM(@c_Option2)     
                         +  ' @c_Facility   = @c_Facility'       
                           +  ',@c_CartonType = @c_CartonType'      
                           +  ',@c_PickSlipNo = @c_PickSlipNo'      
                           +  ',@n_CartonNo   = @n_CartonNo'     
                           +  ',@c_CartonGroupALT= @c_CartonGroupALT OUTPUT'    
                         +  ',@c_AlertMsg   = @c_AlertMsg OUTPUT'            
                
               EXEC sp_executesql @c_SQL       
                  ,  N' @c_Facility       NVARCHAR(5)                                        
                      , @c_CartonType     NVARCHAR(10)        
                      , @c_PickSlipNo     NVARCHAR(10)      
                      , @n_CartonNo       INT    
                      , @c_CartonGroupALT NVARCHAR(10)   OUTPUT    
                      , @c_AlertMsg       NVARCHAR(255)  OUTPUT'    
                  ,  @c_Facility    
                  ,  @c_CartonType         
                  ,  @c_PickSlipNo      
                  ,  @n_CartonNo     
                  ,  @c_CartonGroupALT OUTPUT      
                  ,  @c_AlertMsg       OUTPUT     
    
               IF @c_CartonGroup = '' AND ISNULL(@c_CartonType,'') = '' AND ISNULL(@c_CartonGroupALT,'') <> ''   -- Get Alt Cartontype to show    
               BEGIN    
                  SET @c_CartonGroup = @c_CartonGroupALT    
               END     
            END     
         END    
      END         
   END    
       
   IF @c_CartonGroup= ''                     --(Wan01)-- Move Down      
   BEGIN                                     --(Wan01)      
      SELECT @c_CartonGroup = RTRIM(CartonGroup)      
      FROM STORER WITH (NOLOCK)      
      WHERE Storerkey = @c_Storerkey      
   END                                       --(Wan01)     
                                
   IF @c_authority = '0'    
   BEGIN    
    GOTO QUIT_SP      
   END    
   --(Wan03) - END    
      
   SET @c_SqlWhere = @c_Option5       
    
   --If @c_CartonType <> '' mean it is called from cartongroup and type checking    
   IF @c_CartonType <> '' AND @c_SqlWhere = ''      
   BEGIN      
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
         ,  @c_Option2    OUTPUT      
         ,  @c_Option3    OUTPUT      
         ,  @c_Option4    OUTPUT      
         ,  @c_Option5    OUTPUT      
      
      IF @b_Success <> 1       
      BEGIN       
         GOTO QUIT_SP      
      END      
    
      IF NOT EXISTS (   SELECT 1       
                        FROM CODELKUP WITH (NOLOCK) WHERE ListName = @c_Option1      
                    )      
      BEGIN      
         SET @c_Option5 = ''      
      END      
             
      SET @c_SqlWhere = @c_Option5      
   END      
      
   --(Wan02) - START      
   SET @c_SPCode = ''      
   SELECT @c_SPCode = ISNULL(RTRIM(CL.Long),'')      
   FROM CODELKUP CL WITH (NOLOCK)      
   WHERE CL.ListName  = 'CTNTypMeas'      
   AND   CL.Code      = @c_CartonType      
   AND   CL.Storerkey = @c_Storerkey      
      
   IF ISNULL(RTRIM(@c_SPCode),'') = ''      
   BEGIN        
      GOTO QUIT_SP               
   END      
    
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')      
   BEGIN      
      CREATE TABLE #TMP_CTNTYPMEAS                                    
           (                                                               
              SeqNo             INT            IDENTITY(1,1)               
           ,  CartonizationKey  NVARCHAR(10)   NOT NULL DEFAULT('')        
           ,  CartonType        NVARCHAR(10)   NOT NULL DEFAULT('')        
           ,  Cube              FLOAT          NOT NULL DEFAULT(0.00)      
           ,  MaxWeight         FLOAT          NOT NULL DEFAULT(0.00)      
           ,  MaxCount          INT            NOT NULL DEFAULT(0)         --Alex02 Change datatype from int to float.
           ,  CartonWeight      FLOAT          NOT NULL DEFAULT(0.00)      
           ,  CartonLength      FLOAT          NOT NULL DEFAULT(0.00)      
           ,  CartonWidth       FLOAT          NOT NULL DEFAULT(0.00)      
           ,  CartonHeight      FLOAT          NOT NULL DEFAULT(0.00)      
           )               
         
      SET @c_SQL = 'EXEC ' + @c_SPCode +  ' @c_CartonGroup= @c_CartonGroup'      
                                       +  ',@c_CartonType = @c_CartonType'      
                                       +  ',@c_PickSlipNo = @c_PickSlipNo'      
                                       +  ',@n_CartonNo   = @n_CartonNo'      
      EXEC sp_executesql @c_SQL       
         ,  N' @c_CartonGroup NVARCHAR(10)      
             , @c_CartonType  NVARCHAR(10)       
             , @c_PickSlipNo  NVARCHAR(10)      
             , @n_CartonNo    INT'      
         ,  @c_CartonGroup      
         ,  @c_CartonType      
         ,  @c_PickSlipNo      
         ,  @n_CartonNo         
      
      SELECT  CartonizationKey        
           ,  CartonType              
           ,  Cube                    
           ,  MaxWeight               
           ,  MaxCount                
           ,  CartonWeight            
           ,  CartonLength            
           ,  CartonWidth             
           ,  CartonHeight    
           ,  AlertMsg = @c_AlertMsg      --(Wan04)       
      FROM #TMP_CTNTYPMEAS      
      
      GOTO MEASURE_CUSTOM      
   END      
        
   --(Wan02) - END      
   QUIT_SP:      
      
   MEASURE_STD: --(Wan02)    
   --(WL01): One line can only show 10 carton type, to show next 10 carton type, use mouse scrolling or keyboard up and down arrow button

   SET @c_Sql = N'SELECT TOP 30'  --WL01    --Alex01
              + ' CartonizationKey'      
              + ', CartonType'      
              + ', Cube      = ISNULL(Cube,0)'      
              + ', MaxWeight = ISNULL(MaxWeight,0)'    
              + ', MaxCount  = ISNULL(MaxCount,0)'      
              + ', CartonWeight = ISNULL(CartonWeight,0)'      
              + ', CartonLength = ISNULL(CartonLength,0)'      
              + ', CartonWidth  = ISNULL(CartonWidth,0)'      
              + ', CartonHeight = ISNULL(CartonHeight,0)'     
              + ', AlertMsg = @c_AlertMsg'                    
              + ' FROM CARTONIZATION WITH (NOLOCK)'      
              + ' WHERE CartonizationGroup = N''' + RTRIM(@c_CartonGroup) + ''''      
              --+ ' AND  (CartonType = N''' + @c_CartonType + ''' OR ''' + @c_CartonType + '''='''') '            --(Wan03)      
              + CASE WHEN @c_CartonType <> '' THEN ' AND CartonType = N''' + @c_CartonType + '''' ELSE '' END     --(Wan03)     
              + @c_SqlWhere      
              + ' ORDER BY UseSequence'      
   --(Wan03) - START    
   --EXEC ( @c_Sql )     
   SET @c_SQLParms = N'@c_CartonGroup NVARCHAR(10)'    
                   + ',@c_CartonType  NVARCHAR(10)'    
                   + ',@c_AlertMsg    NVARCHAR(255)'     --(Wan04)    
                      
   EXEC sp_ExecuteSQL @c_Sql    
                   ,  @c_SQLParms    
                   ,  @c_CartonGroup    
                   ,  @c_CartonType    
                   ,  @c_AlertMsg                        --(Wan04)    
   --(Wan03) - END     
      
   --(Wan02) - START      
   MEASURE_CUSTOM:      
      
   IF OBJECT_ID('tempdb..#TMP_CTNTYPMEAS','U') IS NOT NULL      
   BEGIN      
      DROP TABLE #TMP_CTNTYPMEAS;      
   END      
   --(Wan02) - END      
      
   ----(Wan01) - START      
   --WHILE @@TRANCOUNT < @n_StartTCnt       
   --BEGIN          
   --   BEGIN TRAN      
   --END      
   ----(Wan01) - END       
END -- procedure 
GO