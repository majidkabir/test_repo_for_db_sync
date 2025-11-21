SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_DeliveryOrder08_rpt                                 */
/* Creation Date: 06-JUL-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5461 - CN - Shaklee_Delivery_Summary_Report             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_DeliveryOrder08_rpt]
            @c_Orderkey        NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
            @n_StartTCnt      INT
         ,  @n_Continue       INT 
         ,  @c_Facility       NVARCHAR(5)              
         ,  @c_Storerkey      NVARCHAR(15)             
         ,  @c_ExternOrderkey NVARCHAR(30)             
         ,  @c_Receiver       NVARCHAR(30)             
         ,  @c_C_Address      NVARCHAR(270)
         ,  @c_OrderPersonNo  NVARCHAR(30)               
         ,  @c_MemberName     NVARCHAR(30)             
         ,  @c_MobileTel      NVARCHAR(18)             
         ,  @d_OrderDate      DATETIME                 
         ,  @n_Freight        FLOAT                    
         ,  @n_TotalWeightFee FLOAT                    
         ,  @n_TotalPay       FLOAT                    
         ,  @c_Notes          NVARCHAR(4000)           
         ,  @c_Source         NVARCHAR(30)             
         ,  @n_TotalPV        FLOAT                    
         ,  @c_StorageName    NVARCHAR(60)
         ,  @n_TotalDiscount  FLOAT 

         ,  @c_Payment        NVARCHAR(100)
         ,  @d_PaymentDate    DATETIME
         ,  @n_Pay            FLOAT 
         ,  @c_Payment1       NVARCHAR(100)
         ,  @d_PaymentDate1   DATETIME
         ,  @n_Pay1           FLOAT 
         ,  @c_Payment2       NVARCHAR(100)
         ,  @d_PaymentDate2   DATETIME
         ,  @n_Pay2           FLOAT 
         ,  @c_Payment3       NVARCHAR(100)
         ,  @d_PaymentDate3   DATETIME
         ,  @n_Pay3           FLOAT
         ,  @c_Payment4       NVARCHAR(100)
         ,  @d_PaymentDate4   DATETIME
         ,  @n_Pay4           FLOAT
         ,  @c_Payment5       NVARCHAR(100)
         ,  @d_PaymentDate5   DATETIME
         ,  @n_Pay5           FLOAT
         ,  @n_DigitalPay     FLOAT
 
         ,  @n_Cnt            INT  
         ,  @c_SQL            NVARCHAR(4000)
         ,  @c_SQLParms       NVARCHAR(4000)

         ,  @CUR_PAYMENT      CURSOR

   DECLARE @n_DocHandle       INT  
   DECLARE @c_XmlDocument     NVARCHAR(4000)             

   SET @n_StartTCnt = @@TRANCOUNT

   CREATE TABLE #TMP_DELORD
         (  
            RowRef         INT            IDENTITY(1,1) PRIMARY KEY
         ,  Facility       NVARCHAR(5)    NULL  DEFAULT('')
         ,  Storerkey      NVARCHAR(15)   NULL  DEFAULT('')
         ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('')
         ,  ExternOrderkey NVARCHAR(30)   NULL  DEFAULT('')
         ,  Receiver       NVARCHAR(30)   NULL  DEFAULT('')      
         ,  C_Address      NVARCHAR(270)  NULL  DEFAULT('')  
         ,  OrderPersonNo  NVARCHAR(30)   NULL  DEFAULT('')    
         ,  MemberName     NVARCHAR(30)   NULL  DEFAULT('')     
         ,  MobileTel      NVARCHAR(18)   NULL  DEFAULT('')     
         ,  OrderDate      DATETIME       NULL  DEFAULT('')
         ,  Freight        FLOAT          NULL  DEFAULT(0.00)     
         ,  TotalWeightFee FLOAT          NULL  DEFAULT(0.00) 
         ,  TotalPay       FLOAT          NULL  DEFAULT(0.00)     
         ,  BuyPay         FLOAT          NULL  DEFAULT(0.00)      
         ,  Discount       FLOAT          NULL  DEFAULT(0.00)      
         ,  DigitalPay     FLOAT          NULL  DEFAULT(0.00)
         ,  Payment1       NVARCHAR(100)  NULL  DEFAULT('')  
         ,  PaymentDate1   DATETIME       NULL  
         ,  Pay1           FLOAT          NULL  DEFAULT(0.00) 
         ,  Payment2       NVARCHAR(100)  NULL  DEFAULT('') 
         ,  PaymentDate2   DATETIME       NULL
         ,  Pay2           FLOAT          NULL  DEFAULT(0.00)    
         ,  Payment3       NVARCHAR(100)  NULL  DEFAULT('')
         ,  PaymentDate3   DATETIME       NULL    
         ,  Pay3           FLOAT          NULL  DEFAULT(0.00) 
         ,  Payment4       NVARCHAR(100)  NULL  DEFAULT('')  
         ,  PaymentDate4   DATETIME       NULL  
         ,  Pay4           FLOAT          NULL  DEFAULT(0.00) 
         ,  Payment5       NVARCHAR(100)  NULL  DEFAULT('') 
         ,  PaymentDate5   DATETIME       NULL
         ,  Pay5           FLOAT          NULL  DEFAULT(0.00) 
         ,  [Source]       NVARCHAR(30)   NULL  DEFAULT('')
         ,  TotalPV        FLOAT          NULL  DEFAULT(0.00)     
         ,  StorageName    NVARCHAR(60)   NULL  DEFAULT('')
         ,  SubSkuGroup    INT            NULL  DEFAULT(0)
         ,  SkuRank        NVARCHAR(30)   NULL  DEFAULT('')
         ,  Sku_MovePos    INT            NULL  DEFAULT(0)
         ,  SKU            NVARCHAR(30)   NULL  DEFAULT('')
         ,  SKUDescr       NVARCHAR(60)   NULL  DEFAULT('')
         ,  Unit           NVARCHAR(10)   NULL  DEFAULT('') 
         ,  Qty            INT            NULL  DEFAULT(0) 
         ,  NetWeight      FLOAT          NULL  DEFAULT(0.00) 
         ,  UnitPrice      FLOAT          NULL  DEFAULT(0.00)
         ,  SubPay         FLOAT          NULL  DEFAULT(0.00)    
         )  

   CREATE TABLE #TMP_ORDSKU
      (     
            RowRef         INT            IDENTITY(1,1) PRIMARY KEY
         ,  RecRef         INT            NULL  
         ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('')
         ,  Storerkey      NVARCHAR(15)   NULL  DEFAULT('')
         ,  SubSkuGroup    INT            NULL  DEFAULT(0)
         ,  SKU            NVARCHAR(30)   NULL  DEFAULT('') 
         ,  Sku_MovePos    INT            NULL  DEFAULT(0)
         ,  SetSku         NVARCHAR(20)   NULL  DEFAULT('')
         ,  SetUnit        NVARCHAR(10)   NULL  DEFAULT('')
         ,  SetQty         INT            NULL  DEFAULT(0)
         ,  ODSKU          NVARCHAR(20)   NULL  DEFAULT('')
         ,  SKUDescr       NVARCHAR(60)   NULL  DEFAULT('')
         ,  Unit           NVARCHAR(10)   NULL  DEFAULT('') 
         ,  Qty            INT            NULL  DEFAULT(0) 
         ,  NetWeight      FLOAT          NULL  DEFAULT(0.00)
         ,  UnitPrice      FLOAT          NULL  DEFAULT(0.00)  
         ,  SubPay         FLOAT          NULL  DEFAULT(0.00)   
         ,  Discount       FLOAT          NULL  DEFAULT(0.00)
      )  
   
   SET @c_Facility      = ''              
   SET @c_Storerkey     = ''            
   SET @c_ExternOrderkey= ''              
   SET @c_Receiver      = ''             
   SET @c_C_Address     = ''   
   SET @c_OrderPersonNo = ''               
   SET @c_MemberName    = ''            
   SET @c_MobileTel     = ''                
   SET @n_Freight       = 0.00                    
   SET @n_TotalWeightFee= 0.00                    
   SET @n_TotalPay      = 0.00                   
   SET @c_Notes         = ''              
   SET @c_Source        = ''               
   SET @n_TotalPV       = 0.00                   
   SET @c_StorageName   = ''    

   SELECT                                                                                                                               
           @c_Facility       = OH.Facility                                                                                                                     
         , @c_Storerkey      = OH.Storerkey                                                                                                                    
         , @c_Orderkey       = OH.Orderkey                                                                                                                     
         , @c_ExternOrderkey = OH.ExternOrderkey                                                                                                               
         , @c_Receiver       = ISNULL(RTRIM(OH.C_Contact1),'') + ' '                                                                               
         , @c_C_Address      = ISNULL(RTRIM(OH.C_State),'') + ' '                                                                                  
                             + ISNULL(RTRIM(OH.C_City),'') + ' '                                                                                   
                             + ISNULL(RTRIM(OH.C_Address1),'') + ' '                                                                               
                             + ISNULL(RTRIM(OH.C_Address2),'') + ' '                                                                               
                             + ISNULL(RTRIM(OH.C_Address3),'') + ' '                                                                               
                             + ISNULL(RTRIM(OH.C_Address4),'')                                                                                     
         , @c_OrderPersonNo  = ISNULL(RTRIM(OH.B_Contact1),'')                                                                                  
         , @c_MemberName     = ISNULL(RTRIM(OH.B_Contact2),'')                                                                                  
         , @c_MobileTel      = ISNULL(RTRIM(OH.B_Phone2),'')                                                                                    
         , @d_OrderDate      = OH.OrderDate                                                                                                                    
         , @n_Freight        = CASE WHEN ISNUMERIC(ISNULL(RTRIM(OH.UserDefine01),'')) = 1 
                                    THEN CONVERT(FLOAT, ISNULL(RTRIM(OH.UserDefine01),'')) 
                                    ELSE 0.00 END 
         , @n_TotalWeightFee = CASE WHEN ISNUMERIC(ISNULL(RTRIM(OH.UserDefine02),'')) = 1 
                                    THEN CONVERT(FLOAT, ISNULL(RTRIM(OH.UserDefine02),'')) 
                                    ELSE 0.00 END 
         , @n_TotalPay       = ISNULL(OH.InvoiceAmount,0.00)                                                                                   
         , @c_Notes          = ISNULL(RTRIM(OH.Notes),'')                                                                                           
         , @c_Source         = ISNULL(RTRIM(OI.OrderInfo01),'')                                                                                     
         , @n_TotalPV        = CASE WHEN ISNUMERIC(ISNULL(RTRIM(OI.OrderInfo04),'')) = 1 
                                    THEN CONVERT(FLOAT, ISNULL(RTRIM(OI.OrderInfo04),''))
                                    ELSE 0.00 END                      
   FROM ORDERS         OH WITH (NOLOCK)                                                                                                    
   LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON (OH.Orderkey = OI.Orderkey)                                                                     
   WHERE OH.Orderkey = @c_Orderkey  

   SET @c_StorageName = ''
   SELECT TOP 1 @c_StorageName = ISNULL(RTRIM(UDF01),'')
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'SHAKLEEFAC'
   AND   Storerkey= @c_Storerkey
   AND   Short    = @c_Facility
 
   -- GET Payments - START
   SET @n_Cnt = 0
--select @c_Notes = N'<Pay_Type><Payment>Ê°┴¬╦ó┐¿</Payment><PaymentDate>2018-04-24</PaymentDate><Pay>420</Pay></Pay_Type>'--<Pay_Type><Payment>Íº©Â▒ª</Payment><PaymentDate>2018-06-24</PaymentDate><Pay>400</Pay></Pay_Type>
--<Pay_Type><Payment>Ê°┴¬╦ó┐¿╦ó</Payment><PaymentDate>2018-04-25</PaymentDate><Pay>450</Pay></Pay_Type>'--<Pay_Type><Payment>Íº©Â▒ªÍº©Â▒ª</Payment><PaymentDate>2018-06-26</PaymentDate><Pay>460</Pay></Pay_Type>
--<Pay_Type><Payment>┐¿╦ó</Payment><PaymentDate>2018-04-28</PaymentDate><Pay>480</Pay></Pay_Type>'

   SET @c_Notes = '<Root>' + RTRIM(@c_Notes) + '</Root>'

   EXEC sp_xml_preparedocument @n_DocHandle OUTPUT, @c_Notes  

   SET @CUR_PAYMENT = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT   Payment
         ,  PaymentDate 
         ,  Pay
   FROM OPENXML (@n_DocHandle, '/Root/Pay_Type',2)  
         WITH (Payment     NVARCHAR(100),  
               PaymentDate DATETIME,
               Pay         FLOAT) ; 

   OPEN @CUR_PAYMENT

   FETCH NEXT FROM @CUR_PAYMENT INTO @c_Payment, @d_PaymentDate, @n_Pay

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @n_Cnt = @n_Cnt + 1

      IF @n_Cnt >= 6 
         BREAK
       
      SET @c_SQL = N'SET @c_Payment' + RTRIM(CONVERT(NCHAR(1),@n_Cnt)) + ' = @c_Payment'
                 + ' SET @d_PaymentDate' + RTRIM(CONVERT(NCHAR(1),@n_Cnt)) + ' = @d_PaymentDate'
                 + ' SET @n_Pay' + RTRIM(CONVERT(NCHAR(1),@n_Cnt)) + ' = @n_Pay'

      SET @c_SQLParms = N'@c_Payment      NVARCHAR(100)'
                      +' ,@d_PaymentDate  DATETIME'
                      +' ,@n_Pay          INT'
                      +' ,@c_Payment1     NVARCHAR(100)  OUTPUT'
                      +' ,@d_PaymentDate1 DATETIME       OUTPUT'
                      +' ,@n_Pay1         INT            OUTPUT'
                      +' ,@c_Payment2     NVARCHAR(100)  OUTPUT'
                      +' ,@d_PaymentDate2 DATETIME       OUTPUT'
                      +' ,@n_Pay2         INT            OUTPUT'
                      +' ,@c_Payment3     NVARCHAR(100)  OUTPUT'
                      +' ,@d_PaymentDate3 DATETIME       OUTPUT'
                      +' ,@n_Pay3         INT            OUTPUT'
                      +' ,@c_Payment4     NVARCHAR(100)  OUTPUT'
                      +' ,@d_PaymentDate4 DATETIME       OUTPUT'
                      +' ,@n_Pay4         INT            OUTPUT'
                      +' ,@c_Payment5     NVARCHAR(100)  OUTPUT'
                      +' ,@d_PaymentDate5 DATETIME       OUTPUT'
                      +' ,@n_Pay5         INT            OUTPUT'

      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_Payment      
                        ,@d_PaymentDate
                        ,@n_Pay 
                        ,@c_Payment1      OUTPUT     
                        ,@d_PaymentDate1  OUTPUT
                        ,@n_Pay1          OUTPUT
                        ,@c_Payment2      OUTPUT     
                        ,@d_PaymentDate2  OUTPUT
                        ,@n_Pay2          OUTPUT
                        ,@c_Payment3      OUTPUT     
                        ,@d_PaymentDate3  OUTPUT
                        ,@n_Pay3          OUTPUT
                        ,@c_Payment4      OUTPUT     
                        ,@d_PaymentDate4  OUTPUT
                        ,@n_Pay4          OUTPUT
                        ,@c_Payment5      OUTPUT     
                        ,@d_PaymentDate5  OUTPUT
                        ,@n_Pay5          OUTPUT

      IF @c_Payment = N'ÁþÎË╚»'
         SET @n_DigitalPay = @n_Pay

      FETCH NEXT FROM @CUR_PAYMENT INTO @c_Payment, @d_PaymentDate, @n_Pay
   END
   CLOSE @CUR_PAYMENT
   DEALLOCATE @CUR_PAYMENT

   EXEC sp_xml_removedocument @n_DocHandle 
   -- GET Payments - END 

   INSERT INTO #TMP_ORDSKU
      (
         RecRef
      ,  Orderkey      
      ,  Storerkey
      ,  SubSkuGroup 
      ,  SKU
      ,  SetSKU
      ,  SetUnit
      ,  SetQty
      ,  ODSKU 
      ,  SKUDescr   
      ,  Unit           
      ,  Qty   
      ,  NetWeight     
      ,  UnitPrice      
      ,  SubPay         
      ,  Discount      
      )  
   SELECT
         RecRef         = ROW_NUMBER() OVER (ORDER BY ISNULL(RTRIM(OD.UserDefine01),'') DESC)
      ,  Orderkey       = OD.ORderkey
      ,  Storerkey      = OD.Storerkey
      ,  SubSkuGroup    = 0
      ,  SKU            = OD.Sku
      ,  SetSku         = ISNULL(RTRIM(OD.UserDefine01),'')
      ,  SetUnit        = ISNULL(RTRIM(OD.UserDefine03),'')
      ,  SetQty         = CASE WHEN ISNUMERIC(ISNULL(RTRIM(OD.UserDefine02),'')) = 1 
                               THEN ISNULL(RTRIM(OD.UserDefine02),'') 
                               ELSE 0 END 
      ,  ODSKU          = OD.Sku                      
      ,  SKUDescr       = ''
      ,  Unit           = OD.UOM                      
      ,  Qty            = ISNULL(SUM(OD.OpenQty),0) 
      ,  NetWeight      = CASE WHEN ISNUMERIC(ISNULL(RTRIM(OD.UserDefine10),'')) = 1 
                               THEN CONVERT(FLOAT, ISNULL(RTRIM(OD.UserDefine10),'')) 
                               ELSE 0.00 END 
      ,  UnitPrice      = ISNULL(OD.UnitPrice,0.00)   
      ,  SubPay         = CASE WHEN ISNUMERIC(ISNULL(RTRIM(OD.UserDefine08),'')) = 1 
                               THEN CONVERT(FLOAT, ISNULL(RTRIM(OD.UserDefine08),'')) 
                               ELSE 0.00 END 

      ,  Discount       = CASE WHEN ISNUMERIC(ISNULL(RTRIM(OD.UserDefine09),'')) = 1 
                                   THEN CONVERT(FLOAT, ISNULL(RTRIM(OD.UserDefine09),''))
                                   ELSE 0.00 END                                      
   FROM ORDERS      OH WITH (NOLOCK)  
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Orderkey = @c_Orderkey 
   GROUP BY OD.ORderkey
         ,  OD.Storerkey
         ,  OD.Sku  
         ,  ISNULL(OD.UnitPrice,0.00)
         ,  OD.UOM
         ,  ISNULL(RTRIM(OD.UserDefine01),'')
         ,  ISNULL(RTRIM(OD.UserDefine02),'')
         ,  ISNULL(RTRIM(OD.UserDefine03),'')
         ,  ISNULL(RTRIM(OD.UserDefine08),'')
         ,  ISNULL(RTRIM(OD.UserDefine09),'')
         ,  ISNULL(RTRIM(OD.UserDefine10),'')

 
  INSERT INTO #TMP_ORDSKU
      (  
         RecRef
      ,  Orderkey      
      ,  Storerkey
      ,  SubSkuGroup 
      ,  SKU  
      ,  SetSKU
      ,  SetUnit
      ,  SetQty
      ,  ODSKU 
      ,  Unit           
      ,  Qty   
      ,  NetWeight     
      ,  UnitPrice      
      ,  SubPay         
      ,  Discount     
      )  
   SELECT 
         RecRef   = MIN(OD.RecRef)
      ,  Orderkey = OD.Orderkey      
      ,  Storerkey= OD.Storerkey
      ,  SubSkuGroup= 1
      ,  Sku      = OD.SetSKU + '(' + OD.SetUnit + ')'
      ,  SetSKU   = OD.SetSKU
      ,  SetUnit  = OD.SetUnit 
      ,  SetQty   = MAX(OD.SetQty)
      ,  ODSku    = OD.SetSKU
      ,  Unit     = OD.SetUnit          
      ,  Qty      = MAX(OD.SetQty) 
      ,  NetWeight= SUM(OD.NetWeight)        
      ,  UnitPrice= MAX(OD.UnitPrice)
      ,  SubPay   = MAX(OD.SubPay)         
      ,  Discount = MAX(Discount) 
   FROM #TMP_ORDSKU OD
   WHERE OD.Orderkey = @c_Orderkey
   AND OD.SetSKU <> ''
   GROUP BY OD.Orderkey      
      ,  OD.Storerkey
      ,  OD.SetSKU
      ,  OD.SetUnit

   UPDATE #TMP_ORDSKU
      SET SubSkuGroup = 1
         ,Sku_MovePos = 1
         ,Sku         = '-  ' + Sku
         ,UnitPrice   = NULL
         ,SubPay      = NULL
         ,NetWeight   = NULL
         ,Discount    = 0.00
   WHERE Orderkey = @c_Orderkey
   AND SetSKU <> ''
   AND SubSkuGroup = 0

   UPDATE #TMP_ORDSKU
      SET SKUDescr = ISNULL(RTRIM(SKU.Descr),'')
   FROM #TMP_ORDSKU OD
   JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey)
                          AND(OD.ODSku = SKU.Sku)

   SET @n_TotalDiscount = 0.00
   SELECT @n_TotalDiscount = SUM(ISNULL(OD.Discount,0) * OD.SetQty)
   FROM #TMP_ORDSKU OD
   WHERE OD.Orderkey = @c_Orderkey

   INSERT INTO #TMP_DELORD
      (
         Facility       
      ,  Storerkey      
      ,  Orderkey       
      ,  ExternOrderkey 
      ,  Receiver       
      ,  C_Address
      ,  OrderPersonNo      
      ,  MemberName     
      ,  MobileTel      
      ,  OrderDate      
      ,  Freight        
      ,  TotalWeightFee 
      ,  TotalPay       
      ,  BuyPay         
      ,  Discount
      ,  DigitalPay       
      ,  Payment1
      ,  PaymentDate1
      ,  Pay1  
      ,  Payment2
      ,  PaymentDate2
      ,  Pay2  
      ,  Payment3
      ,  PaymentDate3
      ,  Pay3 
      ,  Payment4
      ,  PaymentDate4
      ,  Pay4    
      ,  Payment5
      ,  PaymentDate5
      ,  Pay5   
      ,  [Source]       
      ,  TotalPV        
      ,  StorageName 
      ,  SkuRank
      ,  SubSkuGroup 
      ,  Sku_MovePos  
      ,  SKU            
      ,  SKUDescr       
      ,  Unit           
      ,  Qty  
      ,  NetWeight   
      ,  UnitPrice            
      ,  SubPay         
      )  
   SELECT 
         Facility       = @c_Facility           
      ,  Storerkey      = @c_Storerkey          
      ,  Orderkey       = @c_Orderkey           
      ,  ExternOrderkey = @c_ExternOrderkey     
      ,  Receiver       = @c_Receiver           
      ,  C_Address      = @c_C_Address          
      ,  OrderPersonNo  = @c_OrderPersonNo      
      ,  MemberName     = @c_MemberName         
      ,  MobileTel      = @c_MobileTel          
      ,  OrderDate      = @d_OrderDate          
      ,  Freight        = @n_Freight            
      ,  TotalWeightFee = @n_TotalWeightFee     
      ,  TotalPay       = @n_TotalPay           
      ,  BuyPay         = @n_TotalPay - @n_TotalDiscount
      ,  Discount       = -1 * @n_TotalDiscount
      ,  DigitalPay     = -1 * @n_DigitalPay
      ,  Payment1       = @c_Payment1
      ,  PaymentDate1   = @d_PaymentDate1
      ,  Pay1           = @n_Pay1
      ,  Payment2       = @c_Payment2
      ,  PaymentDate2   = @d_PaymentDate2
      ,  Pay2           = @n_Pay2
      ,  Payment3       = @c_Payment3
      ,  PaymentDate3   = @d_PaymentDate3
      ,  Pay3           = @n_Pay3
      ,  Payment4       = @c_Payment4
      ,  PaymentDate4   = @d_PaymentDate4
      ,  Pay4           = @n_Pay4
      ,  Payment5       = @c_Payment5
      ,  PaymentDate5   = @d_PaymentDate5
      ,  Pay5           = @n_Pay5
      ,  [Source]       = @c_Source                                    
      ,  TotalPV        = @n_TotalPV                                   
      ,  StorageName    = @c_StorageName  
      ,  SkuRank        = CASE WHEN OD.SetSku = '' THEN OD.Sku ELSE OD.SetSku END
      ,  SubSkuGroup    = OD.SubSkuGroup
      ,  Sku_MovePos    = OD.Sku_MovePos
      ,  SKU            = OD.Sku                   
      ,  SKUDescr       = OD.SKUDescr
      ,  Unit           = OD.Unit 
      ,  Qty            = OD.Qty
      ,  NetWeight      = OD.NetWeight 
      ,  UnitPrice      = OD.UnitPrice
      ,  SubPay         = (OD.SubPay * OD.SetQty) - (OD.Discount * OD.SetQty)
   FROM #TMP_ORDSKU OD
   WHERE OD.Orderkey = @c_Orderkey 
   ORDER BY OD.SubSkuGroup DESC
          , OD.RecRef
          , OD.Sku DESC


QUIT_SP:
   SELECT   SortBy  = ROW_NUMBER() OVER (ORDER BY OH.Storerkey
                                                , OH.SubSkuGroup DESC
                                                , OH.RowRef
                                        )
         ,  PageNo  = CEILING(ROW_NUMBER() OVER (ORDER BY OH.Storerkey
                                                , OH.SubSkuGroup DESC
                                                , OH.RowRef
                                        )/17.0)
         ,  DataRank = RANK() OVER (ORDER BY OH.Storerkey
                                           , OH.SubSkuGroup DESC
                                           , OH.SkuRank
                                          )
         ,  OH.Facility              
         ,  OH.Storerkey             
         ,  OH.Orderkey              
         ,  OH.ExternOrderkey        
         ,  OH.Receiver              
         ,  OH.C_Address             
         ,  OH.OrderPersonNo         
         ,  OH.MemberName            
         ,  OH.MobileTel             
         ,  OH.OrderDate             
         ,  OH.Freight               
         ,  OH.TotalWeightFee        
         ,  OH.TotalPay              
         ,  OH.BuyPay                
         ,  OH.Discount   
         ,  OH.DigitalPay
         ,  OH.Payment1              
         ,  OH.PaymentDate1          
         ,  OH.Pay1                  
         ,  OH.Payment2              
         ,  OH.PaymentDate2          
         ,  OH.Pay2                  
         ,  OH.Payment3              
         ,  OH.PaymentDate3          
         ,  OH.Pay3   
         ,  OH.Payment4              
         ,  OH.PaymentDate4       
         ,  OH.Pay4   
         ,  OH.Payment5             
         ,  OH.PaymentDate5       
         ,  OH.Pay5              
         ,  OH.[Source]              
         ,  OH.TotalPV               
         ,  OH.StorageName 
         ,  OH.SubSkuGroup 
         ,  OH.Sku_MovePos               
         ,  OH.SKU                   
         ,  OH.SKUDescr              
         ,  OH.Unit                  
         ,  OH.Qty 
         ,  OH.NetWeight 
         ,  OH.UnitPrice                   
         ,  OH.SubPay                
   FROM #TMP_DELORD OH
   ORDER BY SortBy

   DROP TABLE #TMP_DELORD
END -- procedure

GO