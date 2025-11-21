SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenerateSOfromKit                                       */
/* Creation Date: 13-Sep-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose:  Generate SO from RCM in KitDetailFrom                      */
/*                                                                      */
/* Input Parameters:  @c_KitKey                                         */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Rev  Purposes                                   */
/* 11-Nov-2014 CSCHONG  1.0  SOS321334  (CS01)                          */
/* 03-May-2016 NJOW01   1.1 369246-Change field mappings                */
/* 28-Jan-2019 TLTING_ext 1.2  enlarge externorderkey field length      */
/* 06-Jan-2021 MINGLE   1.3  LFWM-3178 - get facility from code2(ML01)  */  
/* 06-Jan-2021 Mingle   1.3  DevOps Combine Script                      */  
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispGenerateSOfromKit]
   @c_KitKey     NVARCHAR(10),
   @c_Ordertype  NVARCHAR(10)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_ExternOrderKey    NVARCHAR(50),   --tlting_ext
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
            @n_OpenQty           int,
            @n_LineNo            int,
            @c_Udf01             NVARCHAR(60),            --(CS01)
            @c_susr2             NVARCHAR(18),            --(CS01)
            @n_slife1            int,                     --(CS01)
            @n_slife2            int,                      --(CS01)
            @n_slife             int,                      --(CS01)
            @c_ExternKitKey      NVARCHAR(20), --NJOW01
            @c_UsrDef2           NVARCHAR(18), --NJOW01
            @d_EffectiveDate     DATETIME, --NJOW01
            @c_Remarks           NVARCHAR(200), --NJOW01
            @c_getStorerKey      NVARCHAR(15)               --(ML01)
            
   DECLARE @n_continue        int,
           @b_success         int,
           @n_err             int,
           @c_errmsg          NVARCHAR(255)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SELECT @c_Lottable01 = ''
   
   --START ML01  
   SELECT @c_getStorerKey = KIT.Storerkey  
   FROM KIT (NOLOCK)  
   WHERE  KIT.KitKey = @c_KitKey  
   --END ML01 

   -- insert into Order Header
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_StorerKey = KIT.Storerkey,
             @c_BuyerPO = KIT.CustomerRefNo,
             @c_ExternKitKey = ISNULL(KIT.ExternKitKey,''), --NJOW01
             @c_UsrDef2 = ISNULL(KIT.UsrDef2,''), --NJOW01
             @d_EffectiveDate = KIT.EffectiveDate, --NJOW01
             @c_Remarks = ISNULL(KIT.Remarks,'') --NJOW01
      FROM   KIT (NOLOCK)
      WHERE  KIT.KitKey = @c_KitKey
      
      --START ML01  
      SELECT @c_Facility = dbo.fnc_RTrim(Code2)  
      FROM   Codelkup (NOLOCK)   
      WHERE  Code = @c_getStorerKey  
      AND    Listname = 'KIT2SO'  
      --END ML01  
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF dbo.fnc_RTrim(@c_StorerKey) IS NOT NULL
      BEGIN
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
            /* P&G Future Consideration - Insert UserDefine08 value = '2' */
            INSERT INTO ORDERS (OrderKey, ExternOrderKey, BuyerPO, StorerKey, Type, OrderGroup, Facility, C_Company, DeliveryDate, Notes, Userdefine01)  --NJOW01
            VALUES (@c_NewOrderKey, @c_ExternKitKey, @c_BuyerPO, @c_StorerKey, @c_Ordertype, 'KIT', @c_Facility, @c_UsrDef2, @d_EffectiveDate, @c_Remarks, @c_KitKey)  --ML01  
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
      --START ML01  
      IF dbo.fnc_RTrim(@c_Facility) IS NULL  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526     
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Codelkup Code2 is BLANK! (ispGenerateSOfromKit)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
      --END ML01 
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

         /*CS01 Start*/
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

            IF isnumeric(@c_udf01)=1
            Begin
               SELECT @n_slife1 = convert(int,@c_udf01)
            END
            ELSE
            BEGIN
               SELECT @n_slife1 = 0
            END

            IF ISNUMERIC(@c_susr2)=1
            BEGIN
               SELECT @n_slife2=convert(int,@c_susr2)
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

         /*CS01 End*/
         SELECT @c_OrderLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5)

         INSERT INTO ORDERDETAIL (OrderKey,                OrderLineNumber,      ExternOrderKey,
                                  ExternLineNo,            StorerKey,            SKU,
                                  OpenQty,                 UOM,                  PackKey,
                                  Lottable01,MinShelfLife)              --(CS01)
                     VALUES      (@c_NewOrderKey,          @c_OrderLine,         @c_ExternKitKey, --NJOW01
                                  @c_ExternOrderLine,      @c_StorerKey,         @c_SKU,
                                  ISNULL(@n_OpenQty, 0),   @c_UOM,               @c_PackKey,
                                  ISNULL(@c_Lottable01,''),@n_slife)         --(CS01)

         SELECT @n_LineNo = @n_LineNo + 1

    FETCH NEXT FROM C_INSERTOD INTO @c_SKU, @c_PackKey, @c_UOM, @n_OpenQty, @c_ExternOrderLine

   END -- While header
   CLOSE C_INSERTOD
   DEALLOCATE C_INSERTOD
  END -- if continue = 1 or 2 001


GO