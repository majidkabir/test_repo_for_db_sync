SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_AEO                                             */
/* Creation Date: 18-DEC-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#297511:Auto Create ASN for AEO ECOM Orders              */
/*                                                                      */
/* Input Parameters: Orderkey                                           */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/*Date         Author  Ver. Purposes                                    */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_AEO] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternReceiptKey   NVARCHAR(20)
         , @c_Facility           NVARCHAR(5)
         , @c_StorerKey          NVARCHAR(15)
         , @c_Type               NVARCHAR(10)
         , @c_consigneekey       NVARCHAR(15)
         , @c_UserDefine04       NVARCHAR(30)

         , @c_SKU                NVARCHAR(20)
         , @c_SKUDescr           NVARCHAR(60)
         , @c_RetailSku          NVARCHAR(20)
         , @c_ALTSku             NVARCHAR(20)
         , @c_ManufacturerSku    NVARCHAR(20)
         , @n_StdNetWgt          FLOAT 
         , @n_StdCube            FLOAT 
         , @c_SkuGroup           NVARCHAR(10)    
         , @n_Price              money         
         , @c_Style              NVARCHAR(20)    
         , @c_Color              NVARCHAR(10)    
         , @c_Size               NVARCHAR(5)    
         , @c_Lottable05Label    NVARCHAR(20) 

         , @c_Strategykey        NVARCHAR(10)
         , @c_PackKey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(5) 

         , @c_ToFacility         NVARCHAR(5) 
         , @c_ToStorerKey        NVARCHAR(15)

 
         , @c_OrderLine          NVARCHAR(5) 
         , @c_ExternOrderLine    NVARCHAR(10)
         , @c_NewReceiptKey      NVARCHAR(10) 
         , @c_ReceiptLine        NVARCHAR(5)
         , @c_ToLoc              NVARCHAR(10)
         , @c_rdUserdefine01     NVARCHAR(30)
         , @c_rdUserdefine02     NVARCHAR(30) 
         , @n_QtyReceived        INT
         , @n_Qty                INT
         , @n_PackQty            INT
         , @c_PickSlipNo         NVARCHAR(10)

         , @n_LineNo             INT 

   DECLARE @n_starttcnt          INT
           
   DECLARE @n_continue           INT
         , @b_success            INT
         , @n_err                INT
         , @c_errmsg             NVARCHAR(255)

   SET @n_continue = 1
   SET @b_success  = 1
   SET @n_err = 0
   
   SET @n_StartTCnt=@@TRANCOUNT 
   BEGIN TRAN

   CREATE TABLE #TMP_PACK 
      (     PickSlipNo  NVARCHAR(10) NOT NULL DEFAULT ('')
          , DropID      NVARCHAR(20) NOT NULL DEFAULT ('')
          , Storerkey   NVARCHAR(15) NOT NULL DEFAULT ('')
          , Sku         NVARCHAR(20) NOT NULL DEFAULT ('')
          , QtyPacked   INT          NOT NULL DEFAULT (0)
      )

   -- insert into Receipt Header
   SELECT @c_ExternReceiptKey  = CASE WHEN ISNULL(STORER.Susr5,'') = '1'  
                                      THEN ISNULL(ORDERS.Buyerpo,'')
                                      ELSE LEFT(ISNULL(ORDERS.ExternOrderkey,''),20) END 
      ,  @c_Type               = ORDERS.Type 
      ,  @c_Facility           = ORDERS.Facility
      ,  @c_ToFacility         = ISNULL(STORER.Susr4,'')              
      ,  @c_ToStorerkey        = ISNULL(STORER.Susr2,'')  
      ,  @c_Storerkey          = ORDERS.Storerkey 
      ,  @c_Consigneekey       = ORDERS.Consigneekey 
      ,  @c_ToLoc              = CASE WHEN ISNULL(FACILITY.UserDefine04,'') = '' 
                                      THEN 'STAGE'  
                                      ELSE ISNULL(FACILITY.UserDefine04,'')
                                      END 
      ,  @c_Strategykey        = ISNULL(STORER.Susr3,'')
      ,  @c_RDUSerDefine02     = ISNULL(ORDERS.ExternOrderkey,'')
      ,  @c_UserDefine04       = ISNULL(STORER.Susr1,'') 
   FROM  ORDERS WITH (NOLOCK)
   JOIN  STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
   LEFT JOIN  FACILITY WITH (NOLOCK) ON STORER.Susr4 = FACILITY.Facility 
   WHERE ORDERS.OrderKey = @c_OrderKey
  
   
   IF NOT EXISTS ( SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE Facility = @c_ToFacility )
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(char(250),@n_err)
      SET @n_err = 63490   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid To Facility: ' + RTRIM(ISNULL(@c_ToFacility,'')) +
                     ' (ispPopulateTOASN_AEO)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      GOTO QUIT_SP
   END
    
   IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc) 
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(char(250),@n_err)
      SET @n_err = 63495   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid To Loc: ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                     ' (ispPopulateTOASN_AEO)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      GOTO QUIT_SP
   END
    
   IF NOT EXISTS ( SELECT 1 FROM STRATEGY WITH (NOLOCK) WHERE StrategyKey = @c_StrategyKey)
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(char(250),@n_err)
      SET @n_err = 63497   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Strategy: ' + RTRIM(ISNULL(@c_StrategyKey,'')) +
                     ' (ispPopulateTOASN_AEO)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      GOTO QUIT_SP
   END
   
   IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_ToStorerkey )
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(char(250),@n_err)
      SET @n_err = 63498  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid To Storer Key: ' + RTRIM(ISNULL(@c_ToStorerkey,'')) +
                  ' (ispPopulateTOASN_AEO)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE ExternReceiptkey = @c_ExternReceiptkey AND Storerkey = @c_ToStorerkey) AND @c_ExternReceiptkey <> ''
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(char(250),@n_err)
      SET @n_err = 63501   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ASN ExternReceiptkey Already Exist In System: ' + RTRIM(ISNULL(@c_ExternReceiptkey,'')) +
                  ' (ispPopulateTOASN_AEO)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      GOTO QUIT_SP
   END

         
   IF ISNULL(RTRIM(@c_ToStorerKey),'') = '' -- IS NOT NULL
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(char(250),@n_err)
      SET @n_err = 63499  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_AEO)' + ' ( ' + 
                 ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      GOTO QUIT_SP
   END
   -- get next receipt key
   SET @b_success = 0
   EXECUTE   nspg_getkey
   'RECEIPT'
   , 10
   , @c_NewReceiptKey OUTPUT
   , @b_success OUTPUT
   , @n_err OUTPUT
   , @c_errmsg OUTPUT
   

   IF @b_success = 0
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(char(250),@n_err) 
      SET @n_err = 63500  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_AEO)' 
              + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      GOTO QUIT_SP
   END

   --SELECT @c_UserDefine04 = ISNULL(Short,'')
   --FROM CODELKUP WITH (NOLOCK)
   --WHERE ListName= 'AEOFAC' 
   --AND   Code = @c_Facility


   INSERT INTO RECEIPT 
         (  ReceiptKey
         ,  ExternReceiptkey
         ,  StorerKey
         ,  RecType
         ,  Facility
         ,  DocType
         ,  RoutingTool
         ,  UserDefine02
         ,  UserDefine04
         )
   VALUES 
         ( @c_NewReceiptKey
         , @c_ExternReceiptKey
         , @c_ToStorerKey
         , @c_Type
         , @c_ToFacility
         , 'A'
         , 'N'
         --, @c_Consigneekey
         , ''
         , @c_UserDefine04
         )

   SET @n_err = @@Error

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(char(250),@n_err)
      SET @n_err = 63501   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_AEO)' + ' ( ' + 
                 ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      GOTO QUIT_SP
   END

   SET @n_LineNo = 1     
   SET @c_OrderLine = ''
   SET @c_ExternOrderLine = ''
   
   DECLARE CUR_OD CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT   SKU.SKU                                
         ,  SKU.DESCR                              
         ,  ORDERDETAIL.PackKey                    
         ,  ORDERDETAIL.UOM                        
         ,  ORDERDETAIL.OrderLineNumber            
         ,  ISNULL(ORDERDETAIL.ExternLineNo,'')    
         ,  SKU.RetailSku                          
         ,  SKU.ALTSku                             
         ,  SKU.Manufacturersku                    
         ,  SKU.StdNetWgt                          
         ,  SKU.StdCube                            
         ,  SKU.SkuGroup                           
         ,  SKU.Price                              
         ,  SKU.Style                              
         ,  SKU.Color                              
         ,  SKU.Size                               
         ,  SKU.Lottable05Label                    
   FROM ORDERDETAIL WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
   JOIN SKU    WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
   WHERE ORDERDETAIL.OrderKey = @c_orderkey 
   AND   ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0   
   ORDER by ORDERDETAIL.OrderLineNumber 

   OPEN CUR_OD
   
   FETCH NEXT FROM CUR_OD INTO  @c_SKU                                        
                              , @c_SKUDescr          
                              , @c_PackKey           
                              , @c_UOM               
                              , @c_OrderLine         
                              , @c_ExternOrderLine   
                              , @c_RetailSku         
                              , @c_ALTSku            
                              , @c_ManufacturerSku   
                              , @n_StdNetWgt         
                              , @n_StdCube           
                              , @c_SkuGroup          
                              , @n_Price             
                              , @c_Style             
                              , @c_Color             
                              , @c_Size              
                              , @c_Lottable05Label   

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF NOT EXISTS (SELECT 1 
                     FROM SKU WITH (NOLOCK) 
                     WHERE Storerkey = @c_ToStorerkey 
                     AND Sku = @c_sku) 
      BEGIN 
               
         INSERT INTO SKU 
               (  Storerkey
               ,  SKU
               ,  Descr
               ,  ManufacturerSku
               ,  RetailSku
               ,  ALTSku
               ,  PackKey
               ,  StdNetWgt
               ,  StdCube
               ,  SkuGroup
               ,  Price
               ,  Style
               ,  Color
               ,  Size
               ,  Strategykey
               ,  Lottable05Label   
               )
         VALUES 
               (  @c_ToStorerkey
               ,  @c_Sku
               ,  @c_SkuDescr
               ,  @c_ManufacturerSku
               ,  @c_RetailSku
               ,  @c_ALTSku
               ,  @c_PackKey
               ,  @n_StdNetWgt
               ,  @n_StdCube
               ,  @c_SkuGroup
               ,  @n_Price
               ,  @c_Style
               ,  @c_Color
               ,  @c_Size
               ,  @c_StrategyKey
               ,  @c_Lottable05Label
               )
                                                            
         SET @n_err = @@Error 
                                                            
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 63502   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Error on Table Sku (ispPopulateTOASN_AEO)' + ' ( ' + 
                 ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            GOTO QUIT_SP
         END
      END
     
      SELECT @n_Qty = ISNULL(SUM(PICKDETAIL.Qty),0) 
      FROM PICKDETAIL   WITH (NOLOCK) 
      WHERE PICKDETAIL.OrderKey = @c_OrderKey 
      AND   PICKDETAIL.OrderLineNumber = @c_OrderLine 
     
      SET @n_PackQty = @n_Qty
      SET @c_rdUserDefine01 = ''
      DECLARE CUR_CARTON CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT  PACKHEADER.PickSlipno
            , Dropid = CASE WHEN ISNULL(PACKDETAIL.DropID,'') = ''
                            THEN PACKDETAIL.LabelNo
                            ELSE ISNULL(PACKDETAIL.DropID,'')
                            END
            , PackQty= ISNULL(SUM(PACKDETAIL.Qty),0) - ISNULL(TMP.QtyPacked,0)
      FROM PACKHEADER WITH (NOLOCK)
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipno = PACKDETAIL.Pickslipno)
      LEFT JOIN #TMP_PACK TMP ON (PACKHEADER.PickSlipno = TMP.PickSlipNo)
                              AND(PACKDETAIL.Storerkey = TMP.Storerkey)
                              AND(PACKDETAIL.Sku = TMP.Sku)
                              AND(TMP.DropID = CASE WHEN ISNULL(PACKDETAIL.DropID,'') = ''
                                                    THEN PACKDETAIL.LabelNo
                                                    ELSE PACKDETAIL.DropID
                                                    END)
      WHERE PACKHEADER.Orderkey = @c_Orderkey
      AND   PACKDETAIL.Storerkey= @c_Storerkey
      AND   PACKDETAIL.Sku= @c_Sku
      GROUP BY PACKHEADER.PickSlipno
            ,  CASE WHEN ISNULL(PACKDETAIL.DropID,'') = ''
                    THEN PACKDETAIL.LabelNo
                    ELSE ISNULL(PACKDETAIL.DropID,'')
                    END
            , ISNULL(TMP.QtyPacked,0)
      HAVING ISNULL(SUM(PACKDETAIL.Qty),0) - ISNULL(TMP.QtyPacked,0) > 0

      OPEN CUR_CARTON

      FETCH NEXT FROM CUR_CARTON INTO @c_PickSlipNo
                                    , @c_rdUserDefine01                                        
                                    , @n_PackQty          

      WHILE @n_Qty > 0  -- Loop Pickdetail Qty
      BEGIN
         IF @n_Qty > @n_PackQty
         BEGIN
            SET @n_QtyReceived = @n_PackQty
         END   
         ELSE
         BEGIN
            SET @n_QtyReceived = @n_Qty
         END

         SET @n_Qty = @n_Qty - @n_QtyReceived


         IF @@FETCH_STATUS <> -1       -- If No Packdetail
         BEGIN
            INSERT INTO #TMP_PACK (PickSlipNo, DropID, Storerkey, Sku, QtyPacked)
            VALUES (@c_PickSlipNo, @c_rdUserDefine01, @c_Storerkey, @c_Sku , @n_QtyReceived)
         END 

         SET @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
               
         INSERT INTO RECEIPTDETAIL
               (  ReceiptKey
               ,  ReceiptLineNumber
               ,  ExternReceiptkey    
               ,  ExternLineNo
               ,  StorerKey
               ,  SKU
               ,  QtyExpected
               ,  QtyReceived          
               ,  UOM
               ,  PackKey
               ,  ToLoc
               ,  UserDefine01
               ,  UserDefine02
               ,  BeforeReceivedQty
               ,  FinalizeFlag
               )                                                  
         VALUES        
               (  @c_NewReceiptKey
               ,  @c_ReceiptLine
               ,  @c_ExternReceiptkey
               ,  @c_ExternOrderLine
               ,  @c_ToStorerKey
               ,  @c_SKU
               ,  @n_QtyReceived
               ,  0
               ,  @c_UOM
               ,  @c_Packkey
               ,  @c_Toloc
               ,  @c_rdUserDefine01
               ,  @c_rdUserDefine02
               ,  0
               ,  'N')  
                      
         SET @n_err = @@Error 
                                                         
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 63503  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Error on Table RECEIPTDETAIL (ispPopulateTOASN_AEO)' + ' ( ' + 
                 ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            GOTO QUIT_SP
         END
         SET @n_LineNo = @n_LineNo + 1

         FETCH NEXT FROM CUR_CARTON INTO @c_PickSlipNo
                                       , @c_rdUserDefine01                                        
                                       , @n_PackQty  

         IF @@FETCH_STATUS = -1 AND @n_Qty > 0 -- If No more Packdetail but pickdetail sum qty > 0
         BEGIN
            SET @n_PackQty = @n_Qty
            SET @c_rdUserDefine01 = ''
         END 
      END
      CLOSE CUR_CARTON
      DEALLOCATE CUR_CARTON

      FETCH NEXT FROM CUR_OD INTO  @c_SKU                                        
                                 , @c_SKUDescr          
                                 , @c_PackKey           
                                 , @c_UOM               
                                 , @c_OrderLine         
                                 , @c_ExternOrderLine   
                                 , @c_RetailSku         
                                 , @c_ALTSku            
                                 , @c_ManufacturerSku   
                                 , @n_StdNetWgt         
                                 , @n_StdCube           
                                 , @c_SkuGroup          
                                 , @n_Price             
                                 , @c_Style             
                                 , @c_Color             
                                 , @c_Size              
                                 , @c_Lottable05Label  
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE CUR_OD
   DEALLOCATE CUR_OD
   
   QUIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CUR_CARTON') in (0 , 1)
   BEGIN
      CLOSE CUR_CARTON
      DEALLOCATE CUR_CARTON
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_OD') in (0 , 1)
   BEGIN
      CLOSE CUR_OD
      DEALLOCATE CUR_OD
   END

   DROP TABLE #TMP_PACK

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_AEO'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1

      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END        

END


GO