SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackInsSerialNo_Wrapper                          */
/* Creation Date: 27-08-2021                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17772 - SG- PMI - Packing scan 2D barcode [CR] v1.0     */ 
/*        :                                                             */
/* Called By: Normal packing - Datastore d_ds_getpackinsserialno        */
/*          : of_PackSkuCodeInsertSeriallno                             */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 27-08-2021  Wan      1.0   Created.                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackInsSerialNo_Wrapper]
           @c_PickSlipNo   NVARCHAR(10)
         , @n_CartonNo     INT
         , @c_LabelNo      NVARCHAR(20)
         , @c_LabelLine    NVARCHAR(5)
         , @c_ScanSkuCode  NVARCHAR(50)   = ''
         , @c_Storerkey    NVARCHAR(15)
         , @c_Sku          NVARCHAR(20)
         , @n_Qty          INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT   = @@TRANCOUNT
         , @n_Continue                 INT   = 1
         
         , @b_Success         INT          = 1  
         , @n_Err             INT          = 0   
         , @c_ErrMsg          NVARCHAR(250)= '' 

         , @c_SQL                      NVARCHAR(4000) = ''
         , @c_SQLParms                 NVARCHAR(1000) = ''

         , @c_Facility                 NVARCHAR(5)    = ''
         , @c_Loadkey                  NVARCHAR(10)   = ''
         , @c_Orderkey                 NVARCHAR(10)   = ''
         
         , @c_PackSkuCodeInsSerialNo   NVARCHAR(30)   = ''
         , @c_GetPackInsSerialNo_SP    NVARCHAR(30)   = ''

   IF OBJECT_ID('tempdb..#INSERT_SERIALNO','u') IS NULL
   BEGIN
      CREATE TABLE #INSERT_SERIALNO
      (  SerialNoKey       NVARCHAR(10)   NOT NULL PRIMARY KEY
      ,  SerialNo          NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  OrderKey          NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  OrderLineNumber   NVARCHAR(5)    NOT NULL DEFAULT('')
      ,  StorerKey         NVARCHAR(15)   NOT NULL DEFAULT('')
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')   
      ,  Qty               INT            NOT NULL DEFAULT(0)
      ,  [Status]          NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Externstatus      NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Pickslipno        NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Cartonno          INT            NOT NULL DEFAULT(0)
      ,  LabelLine         NVARCHAR(5)    NOT NULL DEFAULT('')
      ,  id                NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  LotNo             NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  Userdefine01      NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Userdefine02      NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Userdefine03      NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Userdefine04      NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Userdefine05      NVARCHAR(30)   NOT NULL DEFAULT('') 
      ,  SkuCodeCols       NVARCHAR(250) NOT NULL DEFAULT('')    -- Store Additional Column Names in PB Array format for eg. {"userdefine05", "userdefine04"}
      ) 
   END
   
   
   SELECT @c_Loadkey = ph.Loadkey
         ,@c_Orderkey= ph.Orderkey
   FROM dbo.PICKHEADER AS ph WITH (NOLOCK)
   WHERE ph.PickHeaderKey = @c_PickSlipNo
   
   IF @c_Orderkey <> ''
   BEGIN
      SELECT @c_Facility = o.Facility
      FROM dbo.ORDERS AS o WITH (NOLOCK)
      WHERE o.OrderKey = @c_Orderkey
   END
   ELSE
   BEGIN
      SELECT @c_Facility = lp.Facility
      FROM dbo.LoadPlan AS lp WITH (NOLOCK)
      WHERE lp.LoadKey = @c_Loadkey		
   END

   EXEC nspGetRight
      @c_Facility   = @c_Facility  
   ,  @c_StorerKey  = @c_StorerKey 
   ,  @c_sku        = ''       
   ,  @c_ConfigKey  = 'PackSkuCodeInsertSerialNo'
   ,  @b_Success    = @b_Success                OUTPUT
   ,  @c_authority  = @c_PackSkuCodeInsSerialNo OUTPUT 
   ,  @n_err        = @n_err                    OUTPUT
   ,  @c_errmsg     = @c_errmsg                 OUTPUT
   ,  @c_Option1    = @c_GetPackInsSerialNo_SP  OUTPUT

   IF @c_PackSkuCodeInsSerialNo = '0'
   BEGIN
      GOTO QUIT_SP  
   END 
   
   IF @c_GetPackInsSerialNo_SP = ''
   BEGIN  
      GOTO QUIT_SP  
   END 
   
   IF EXISTS (SELECT 1 FROM sys.objects (NOLOCK) where object_id = object_id(@c_GetPackInsSerialNo_SP))
   BEGIN
      SET @c_SQL  = N'EXEC ' + @c_GetPackInsSerialNo_SP 
                  + ' @c_PickSlipNo = @c_PickSlipNo'
                  + ',@n_CartonNo   = @n_CartonNo'  
                  + ',@c_LabelNo    = @c_LabelNo' 
                  + ',@c_LabelLine  = @c_LabelLine'            
                  + ',@c_ScanSkuCode= @c_ScanSkuCode' 
                  + ',@c_Storerkey  = @c_Storerkey' 
                  + ',@c_Sku        = @c_Sku'       
                  + ',@n_Qty        = @n_Qty' 
                        
      SET @c_SQLParms=N' @c_PickSlipNo    NVARCHAR(10)'
                     + ',@n_CartonNo      INT'
                     + ',@c_LabelNo       NVARCHAR(20)'
                     + ',@c_LabelLine     NVARCHAR(5)'                    
                     + ',@c_ScanSkuCode   NVARCHAR(50)'
                     + ',@c_Storerkey     NVARCHAR(15)'
                     + ',@c_Sku           NVARCHAR(20)'
                     + ',@n_Qty           INT'
 
      EXEC sp_executesql @c_SQL
                        ,@c_SQLParms  
                        ,@c_PickSlipNo   
                        ,@n_CartonNo     
                        ,@c_LabelNo 
                        ,@c_LabelLine     
                        ,@c_ScanSkuCode     
                        ,@c_Storerkey    
                        ,@c_Sku          
                        ,@n_Qty 
   END
   
QUIT_SP:
   SELECT 
         SerialNoKey       
      ,  SerialNo          
      ,  OrderKey          
      ,  OrderLineNumber   
      ,  StorerKey         
      ,  Sku               
      ,  Qty               
      ,  [Status]          
      ,  Externstatus      
      ,  Pickslipno        
      ,  Cartonno          
      ,  LabelLine         
      ,  id                
      ,  LotNo             
      ,  Userdefine01      
      ,  Userdefine02      
      ,  Userdefine03      
      ,  Userdefine04      
      ,  Userdefine05
      ,  SkuCodeCols
   FROM #INSERT_SERIALNO  
   ORDER BY SerialNoKey    
   
END -- procedure

GO