SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispGenerateSOfromKit03                                           */
/* Creation Date: 17-Mar-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-19193 - EAT- Generate SO from RCM in KitDetailFrom      */  
/*          Duplicate and modify from ispGenerateSOfromKit              */
/*                                                                      */    
/* Input Parameters:  @c_KitKey                                         */     
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Rev  Purposes                                  */          
/* 17-Mar-2022  WLChooi  1.0  DevOps Combine Script                     */  
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[ispGenerateSOfromKit03]     
   @c_KitKey     NVARCHAR(10),    
   @c_Ordertype  NVARCHAR(10)    
AS   
BEGIN
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF     
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @c_ExternOrderKey    NVARCHAR(50),    
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
           @c_Udf01             NVARCHAR(60),  
           @c_susr2             NVARCHAR(18),  
           @n_slife1            INT,           
           @n_slife2            INT,            
           @n_slife             INT,            
           @c_ExternKitKey      NVARCHAR(20),     
           @c_UsrDef2           NVARCHAR(18),     
           @d_EffectiveDate     DATETIME,         
           @c_Remarks           NVARCHAR(200),    
           @c_getStorerKey      NVARCHAR(15) ,
           @c_Lottable01_OUT    NVARCHAR(18)    
               
   DECLARE @n_continue          INT,    
           @b_success           INT,    
           @n_err               INT,    
           @c_errmsg            NVARCHAR(255)    
    
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0    
   SELECT @c_Lottable01 = ''   
      
   SELECT @c_getStorerKey = KIT.Storerkey    
   FROM KIT (NOLOCK)    
   WHERE KIT.KitKey = @c_KitKey    
    
   -- insert into Order Header    
   IF @n_continue = 1 OR @n_continue = 2     
   BEGIN     
      SELECT @c_StorerKey = KIT.Storerkey,     
             @c_BuyerPO = KIT.CustomerRefNo,    
             @c_ExternKitKey = ISNULL(KIT.ExternKitKey,''),    
             @c_UsrDef2 = ISNULL(KIT.UsrDef2,''),    
             @d_EffectiveDate = KIT.EffectiveDate,    
             @c_Remarks = ISNULL(KIT.Remarks,'')    
      FROM   KIT (NOLOCK)    
      WHERE  KIT.KitKey = @c_KitKey    
       
      SELECT @c_Facility       = dbo.fnc_RTrim(Code2),  
             @c_Lottable01_OUT = TRIM(UDF02)  
      FROM   Codelkup (NOLOCK)     
      WHERE  Code = @c_getStorerKey    
      AND    Listname = 'KIT2SO'    

      SELECT TOP 1 @c_UsrDef2 = TRIM(KITDETAIL.SKU)   
      FROM KITDETAIL (NOLOCK)    
      WHERE KITDETAIL.KitKey = @c_KitKey     
      AND   KITDETAIL.[Type] = 'T'    
      ORDER BY KITDETAIL.KITLineNumber         
   END    
    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN             
      IF dbo.fnc_RTrim(@c_StorerKey) IS NOT NULL    
      BEGIN    
         -- get next order key    
         SELECT @b_success = 0    
         EXECUTE   nspg_getkey    
         'ORDER'    
         , 10    
         , @c_NewOrderKey OUTPUT    
         , @b_success OUTPUT    
         , @n_err OUTPUT    
         , @c_errmsg OUTPUT    
             
         IF @b_success = 1    
         BEGIN     
            INSERT INTO ORDERS (OrderKey, ExternOrderKey, BuyerPO, StorerKey, Type, OrderGroup, Facility, C_Company, DeliveryDate, Notes, Userdefine01)  --NJOW01    
            VALUES (@c_NewOrderKey, @c_ExternKitKey, @c_BuyerPO, @c_StorerKey, @c_Ordertype, 'KIT', @c_Facility, @c_UsrDef2, @d_EffectiveDate, @c_Remarks, @c_KitKey)  --ML01    
         END    
         ELSE    
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526       
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Order Key Failed! (ispGenerateSOfromKit03)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
         END    
      END        
      ELSE    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526       
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispGenerateSOfromKit03)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
      END    
 
      IF dbo.fnc_RTrim(@c_Facility) IS NULL    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526       
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Codelkup Code2 is BLANK! (ispGenerateSOfromKit03)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
      END     
   END -- if continue = 1 or 2    
    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN             
      SELECT @n_LineNo = 1        
  
      DECLARE C_INSERTOD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
         SELECT Sku, PackKey, UOM, ExpectedQty, KITLineNumber    
         FROM KITDETAIL (NOLOCK)    
         WHERE KITDETAIL.KitKey = @c_KitKey     
         AND   KITDETAIL.[Type] = 'F'    
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
         ELSE  
         BEGIN  
            SELECT @c_Lottable01 = @c_Lottable01_OUT  
         END  
 
         SELECT @c_udf01 = ''    
         SELECT @c_susr2 = ''    
            
         SELECT @c_udf01 = Udf01    
         FROM codelkup (NOLOCK)    
         WHERE listname='KIT2SO'    
         AND code = dbo.fnc_RTrim(@c_StorerKey)    
         
         SELECT @c_susr2 = SUSR2    
         FROM SKU (NOLOCK)    
         WHERE SKU = dbo.fnc_RTrim(@c_SKU)    
         AND Storerkey = dbo.fnc_RTrim(@c_StorerKey)    
    
         IF ISNUMERIC(@c_udf01)=1    
         BEGIN    
            SELECT @n_slife1 = CONVERT(INT,@c_udf01)    
         END    
         ELSE    
         BEGIN    
            SELECT @n_slife1 = 0    
         END    
    
         IF ISNUMERIC(@c_susr2)=1     
         BEGIN    
            SELECT @n_slife2=convert(INT,@c_susr2)     
         END    
         ELSE    
         BEGIN    
            SELECT @n_slife2= 0    
         END    
                
         SELECT @n_slife = 0    
    
         IF ISNULL(@c_susr2,'') <> ''    
         BEGIN    
            SELECT @n_slife = @n_slife1 + @n_slife2    
         END    
    
         SELECT @c_OrderLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5)    
    
         INSERT INTO ORDERDETAIL (OrderKey,                 OrderLineNumber,     ExternOrderKey,     
                                  ExternLineNo,             StorerKey,           SKU,     
                                  OpenQty,                  UOM,                 PackKey,    
                                  Lottable01,               MinShelfLife) 
                          VALUES (@c_NewOrderKey,           @c_OrderLine,        @c_ExternKitKey,   
                                  @c_ExternOrderLine,       @c_StorerKey,        @c_SKU,    
                                  ISNULL(@n_OpenQty, 0),    @c_UOM,              @c_PackKey,    
                                  ISNULL(@c_Lottable01,''), @n_slife)   
    
         SELECT @n_LineNo = @n_LineNo + 1    
    
         FETCH NEXT FROM C_INSERTOD INTO @c_SKU, @c_PackKey, @c_UOM, @n_OpenQty, @c_ExternOrderLine    
    
      END -- While header    
      CLOSE C_INSERTOD    
      DEALLOCATE C_INSERTOD    
   END -- if continue = 1 or 2 001    

   IF CURSOR_STATUS('LOCAL', 'C_INSERTOD') IN (0 , 1)
   BEGIN
      CLOSE C_INSERTOD
      DEALLOCATE C_INSERTOD   
   END
END

GO