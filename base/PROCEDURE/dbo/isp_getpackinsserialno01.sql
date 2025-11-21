SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackInsSerialNo01                                */
/* Creation Date: 27-08-2021                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17772 - SG- PMI - Packing scan 2D barcode [CR] v1.0     */ 
/*        :                                                             */
/* Called By: Normal packing - Datastore d_ds_getpackinsserialno        */
/*          : of_PackSkuCodeInsertSeriallno                             */
/*          : isp_GetPackInsSerialNo_Wrapper                            */ 
/*          : Storerconfigkey = PackSkuCodeInsertSerialNo, SP= Option1  */
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
CREATE PROC [dbo].[isp_GetPackInsSerialNo01]
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
           @n_Length                      INT          = 0 
         , @c_UPC                         NVARCHAR(20) = ''
         , @c_2DBarcode                   NVARCHAR(30) = 'N'
         , @b_Success                     INT          = 1  
         , @n_Err                         INT          = 0   
         , @c_ErrMsg                      NVARCHAR(250)= '' 

         , @c_SerialNoKey                 NVARCHAR(10) = ''
         , @c_SerialNo                    NVARCHAR(30) = ''
         , @c_PackKey_UPC                 NVARCHAR(10) = ''
         , @c_UOM_UPC                     NVARCHAR(10) = ''
         , @c_OrderKey                    NVARCHAR(10) = ''
         , @c_OrderLineNumber             NVARCHAR(5)  = ''
         , @c_Status                      NVARCHAR(10 )= '0'
         , @c_UserDefine05                NVARCHAR(30) = ''
         
         , @c_Facility                    NVARCHAR(5)    = ''
         , @c_Loadkey                     NVARCHAR(10)   = ''
         , @c_PackSkuCodeInsSerialNo_Opt5 NVARCHAR(1000) = ''     --SerialNo columns store SkuCode value
         , @c_SkuCodeInSerialCol          NVARCHAR(1000) = ''

   EXEC dbo.ispSKUDC07
     @c_Storerkey = @c_Storerkey   
   , @c_Sku       = @c_ScanSkuCode         
   , @c_NewSku    = @c_UPC          OUTPUT     
   , @c_Code01    = @c_2DBarcode    OUTPUT      

   IF @c_2DBarcode = 'N'
   BEGIN
      GOTO QUIT_SP
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
   ,  @c_authority  = 1
   ,  @b_Success    = @b_Success                      OUTPUT
   ,  @n_err        = @n_err                          OUTPUT
   ,  @c_errmsg     = @c_errmsg                       OUTPUT
   ,  @c_Option5    = @c_PackSkuCodeInsSerialNo_Opt5  OUTPUT
   
   SET @c_SkuCodeInSerialCol = ''
   SELECT @c_SkuCodeInSerialCol = dbo.fnc_GetParamValueFromString('@c_SkuCodeInSerialCol', @c_PackSkuCodeInsSerialNo_Opt5, @c_SkuCodeInSerialCol) 
   
   SET @n_Length = 30
   IF LEN(@c_ScanSkuCode) < 30 SET @n_Length = LEN(@c_ScanSkuCode)
   SET @c_SerialNo = SUBSTRING(@c_ScanSkuCode,1,@n_Length)
   
   IF LEN(@c_ScanSkuCode) > 30 
   BEGIN
      SET @n_Length = LEN(@c_ScanSkuCode)-30
      SET @c_UserDefine05 = SUBSTRING(@c_ScanSkuCode,31,@n_Length)
   END
   
   SELECT @c_Orderkey = p.OrderKey
   FROM dbo.PICKHEADER AS p WITH (NOLOCK)
   WHERE p.PickHeaderKey = @c_PickSlipNo
   
   SELECT @c_OrderLineNumber = o.OrderLineNumber
   FROM dbo.ORDERDETAIL AS o WITH (NOLOCK)
   WHERE o.OrderKey = @c_Orderkey
   AND o.StorerKey = @c_Storerkey
   AND o.Sku = @c_Sku
   
   SELECT @c_UOM_UPC = u.UOM
         ,@c_Packkey_UPC = u.PackKey
   FROM dbo.UPC AS u WITH (NOLOCK)
   WHERE u.StorerKey = @c_Storerkey
   AND u.Sku = @c_Sku
   AND u.UPC = @c_UPC
   
   SELECT @n_Qty = CASE WHEN p.PackUOM1 = @c_UOM_UPC THEN p.CaseCnt
                        WHEN p.PackUOM2 = @c_UOM_UPC THEN p.InnerPack
                        WHEN p.PackUOM8 = @c_UOM_UPC THEN p.OtherUnit1
                        END
   FROM dbo.PACK AS p WITH (NOLOCK)
   WHERE p.PackKey = @c_Packkey_UPC
   
   EXEC dbo.nspg_GetKey
         @KeyName = N'SERIALNO'            
       , @fieldlength = 10                 
       , @keystring = @c_SerialNoKey   OUTPUT
       , @b_Success = @b_Success       OUTPUT
       , @n_err     = @n_err           OUTPUT    
       , @c_errmsg  = @c_errmsg        OUTPUT 
       , @b_resultset = 0              
       , @n_batch = 0                   
   
   IF @b_Success = 0
   BEGIN
   	GOTO QUIT_SP
   END
   
   INSERT INTO #INSERT_SERIALNO
      (  SerialNoKey       
      ,  SerialNo          
      ,  OrderKey          
      ,  OrderLineNumber   
      ,  StorerKey         
      ,  Sku               
      ,  Qty               
      ,  [Status]          
      ,  Pickslipno        
      ,  Cartonno          
      ,  LabelLine         
      ,  Userdefine01      
      ,  Userdefine02      
      ,  Userdefine05
      ,  SkuCodeCols
      )  
   VALUES    
      (  @c_SerialNoKey       
      ,  @c_SerialNo          
      ,  @c_OrderKey          
      ,  @c_OrderLineNumber   
      ,  @c_StorerKey         
      ,  @c_Sku               
      ,  @n_Qty               
      ,  @c_Status          
      ,  @c_Pickslipno        
      ,  @n_Cartonno          
      ,  @c_LabelLine         
      ,  @c_UOM_UPC      
      ,  @c_LabelNo      
      ,  @c_Userdefine05
      ,  @c_SkuCodeInSerialCol
      )      
QUIT_SP:
   
END -- procedure

GO