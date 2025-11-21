SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/      
/* Trigger:  ispGenerateSOfromKit01                                       */      
/* Creation Date: 05-June-2013                                            */      
/* Copyright: LFL                                                         */      
/* Written by: Chong Chin Siang                                           */      
/*                                                                        */      
/* Purpose:  Generate SO from RCM in KitDetailFrom                        */      
/*                                                                        */      
/* Input Parameters:  @c_KitKey                                           */       
/*                                                                        */      
/* Output Parameters:  None                                               */      
/*                                                                        */      
/* PVCS Version: 1.0                                                      */      
/*                                                                        */      
/* Version: 5.4                                                           */      
/*                                                                        */      
/* Data Modifications:                                                    */      
/*                                                                        */      
/* Updates:                                                               */     
/* Date         Author    Purposes                                        */  
/* 05-June-2013 CSCHONG   SOS280287  (CS01)                               */ 
/* 27-Feb-2017  TLTING    Variable Nvarchar                               */ 
/* 27-Mar-2017  NJOW01    WMS-1426 add ordergroup and update minshelflife */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length       */
/**************************************************************************/      
      
CREATE PROCEDURE [dbo].[ispGenerateSOfromKit01]       
   @c_KitKey     NVARCHAR(10),      
   @c_Ordertype  NVARCHAR(10)      
AS      
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF     
      
 DECLARE    @c_ExternOrderKey    NVARCHAR(50),     --tlting_ext  
            @c_SKU               NVARCHAR(20),      
            @c_PackKey           NVARCHAR(10),      
            @c_UOM               NVARCHAR(5),      
            @c_StorerKey         NVARCHAR(15),      
            @c_OrderLine         NVARCHAR(5),      
            @c_Facility          NVARCHAR(5),      
            @c_ExternOrderLine   NVARCHAR(10),      
            @c_BuyerPO           NVARCHAR(20),      
            @c_NewOrderKey       NVARCHAR(20),      
            @c_Lottable01        NVARCHAR(18),      
            @c_SValue            NVARCHAR(1),      
            @n_OpenQty           INT,      
            @n_LineNo            INT,  
            @c_ExternKitKey      nvarchar(20),  --(CS01)    
            @c_lottable03        nvarchar(18),  --(CS01)   
            @c_type              NVARCHAR(10),  --(CS01)  
            @c_minshelflife      NVARCHAR(250), --(CS01)  
            @c_ktype             NVARCHAR(10), --(CS01)  
      	    @c_ItemClass         NVARCHAR(10), --NJOW01
      	    @c_OrderGroup        NVARCHAR(20), --NJOW01
      	    @n_MinShelfLife      INT --NJOW01
      	                   
   DECLARE @n_continue        INT,      
           @b_success         INT,      
           @n_err             INT,      
           @c_errmsg          NVARCHAR(255)      
      
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0      
   SELECT @c_Lottable01 = ''     
   SELECT @c_Lottable03 = ''    
      
   -- insert into Order Header      
   IF @n_continue = 1 OR @n_continue = 2       
   BEGIN       
      SELECT @c_StorerKey = KIT.Storerkey,        
             @c_BuyerPO = KIT.CustomerRefNo,  
             @c_ktype = KIT.type      
      FROM   KIT (NOLOCK)      
      WHERE  KIT.KitKey = @c_KitKey      
   END      
      
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN               
      IF dbo.fnc_RTrim(@c_StorerKey) IS NOT NULL      
      BEGIN      
      	 --NJOW01
 	       SELECT @c_ItemClass = SKU.ItemClass, @c_OrderGroup = CODELKUP.UDF03                               
 	       FROM KITDETAIL(NOLOCK)                             
         JOIN SKU (NOLOCK) ON KITDETAIL.Storerkey = SKU.Storerkey AND KITDETAIL.Sku = SKU.Sku      	 
	       JOIN CODELKUP (NOLOCK) ON CODELKUP.Listname = 'ITEMCLASS' AND CODELKUP.Code = SKU.ItemClass
         WHERE KITDETAIL.Kitkey = @c_Kitkey               
 	       AND KITDETAIL.Type = 'F'                           
 	       GROUP BY SKU.ItemClass, CODELKUP.UDF03                                  
 	       HAVING COUNT(DISTINCT SKU.ItemClass) = 1
 	       
 	       IF ISNULL(@c_ItemClass,'') = ''
 	          SET @c_OrderGroup = 'MIXBRAND'

      	
         -- get next order key      
         SELECT @b_success = 0      
         EXECUTE   nspg_getkey      
         "ORDER"      
         , 10      
         , @c_NewOrderKey OUTPUT      
         , @b_success OUTPUT      
         , @n_err OUTPUT      
         , @c_errmsg OUTPUT      
               
         IF @b_success = 1      
         BEGIN      
            SET @c_Facility = ''    
    
            SELECT TOP 1 @c_Facility = ISNULL(k.Facility, ''),  
                         @c_ExternKitKey = k.Externkitkey      --(CS01)  
            FROM KIT k WITH (NOLOCK)    
            WHERE k.KITKey = @c_KitKey            
              
            SELECT @c_type=short FROM codelkup (NOLOCK)  
            WHERE listname='TRANTYPE'   
            AND code = @c_ktype    
      
            /* P&G Future Consideration - Insert UserDefine08 value = '2' */      
            INSERT INTO ORDERS (OrderKey, ExternOrderKey, BuyerPO, StorerKey, Type, OrderGroup, Facility)   --NJOW01   
            VALUES (@c_NewOrderKey, @c_ExternKitKey, @c_BuyerPO, @c_StorerKey, @c_type, @c_OrderGroup, @c_Facility)    --(CS01)  
                
         END      
         ELSE      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526         
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Order Key Failed! (ispGenerateSOfromKit)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "      
         END      
      END          
      ELSE      
      BEGIN      
         SELECT @n_continue = 3      
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526         
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispGenerateSOfromKit)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "      
      END      
   END -- if continue = 1 or 2      
      
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN               
      SELECT @n_LineNo = 1      
      
      DECLARE C_INSERTOD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
         SELECT Sku, PackKey, UOM, ExpectedQty, KITLineNumber      
             FROM KITDETAIL (NOLOCK)      
             WHERE KITDETAIL.KitKey = @c_KitKey       
             AND   KITDETAIL.Type = 'F'      
         ORDER by KITDETAIL.KITLineNumber      
               
      OPEN C_INSERTOD      
            
      FETCH NEXT FROM C_INSERTOD INTO @c_SKU, @c_PackKey, @c_UOM, @n_OpenQty, @c_ExternOrderLine      
            
      WHILE @@FETCH_STATUS <> -1       
      BEGIN            
         SELECT @c_Lottable01 = ''      
         
         IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE Storerkey = dbo.fnc_RTrim(@c_StorerKey)       
                    AND CONFIGKEY = 'KITPOPHOSTWH' AND sValue = '1')      
         BEGIN      
            SELECT @c_Lottable01 = SUSR4      
            FROM SKU (NOLOCK)      
            WHERE SKU = dbo.fnc_RTrim(@c_SKU)      
            AND Storerkey = dbo.fnc_RTrim(@c_StorerKey)      
         END   
         
         SELECT @c_Lottable03=UDF01 FROM codelkup (NOLOCK)  
         WHERE listname='SKUGROUP'   
         AND code IN (SELECT skugroup FROM sku (NOLOCK)  
                      WHERE sku=@c_SKU and storerkey=@c_Storerkey )     
         /*               
         SELECT @c_minshelflife=long FROM codelkup (NOLOCK)  
         WHERE listname='SKUGROUP'   
         AND code IN (SELECT skugroup FROM sku (NOLOCK)  
                      WHERE sku=@c_SKU and storerkey=@c_Storerkey )                  
         */
         
         --NJOW01
         SELECT @c_minshelflife = CASE WHEN SKU.SkuGroup = 'YFG' THEN CODELKUP.UDF04 
                                       WHEN SKU.SkuGroup = 'YSM2' THEN CODELKUP.UDF05 
                                  ELSE '0' END  
         FROM SKU (NOLOCK) 
	       JOIN CODELKUP (NOLOCK) ON CODELKUP.Listname = 'ITEMCLASS' AND CODELKUP.Code = SKU.ItemClass
	       WHERE SKU.Storerkey = @c_Storerkey
	       AND SKU.Sku = @c_Sku      	 
	       
	       IF ISNUMERIC(@c_minshelflife) = 1
	          SET @n_MinShelfLife = CAST(@c_minshelflife AS INT)
	       ELSE
	          SET @n_MinShelfLife = 0

         
         SELECT @c_OrderLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS Char(5))), 5)      
         
         INSERT INTO ORDERDETAIL (OrderKey,                OrderLineNumber,      ExternOrderKey,       
                                  ExternLineNo,            StorerKey,            SKU,       
                                  OpenQty,                 UOM,                  PackKey,Facility,      
                                  Lottable01,Lottable03,minshelflife)      
                     VALUES      (@c_NewOrderKey,          @c_OrderLine,         @c_ExternKitKey,    --(CS01)  
                                  @c_ExternOrderLine,      @c_StorerKey,         @c_SKU,      
                                  ISNULL(@n_OpenQty, 0),   @c_UOM,               @c_PackKey, @c_Facility, --(CS01)     
                        ISNULL(@c_Lottable01,''),ISNULL(@c_Lottable03,''),@n_minshelflife) --NJOW01     
         
         SELECT @n_LineNo = @n_LineNo + 1      
          
         FETCH NEXT FROM C_INSERTOD INTO @c_SKU, @c_PackKey, @c_UOM, @n_OpenQty, @c_ExternOrderLine      
          
      END -- While header      
      CLOSE C_INSERTOD      
      DEALLOCATE C_INSERTOD      
  END -- if continue = 1 or 2 001

GO