SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */

CREATE PROCedure [dbo].[isp_packinglist_detail_01](
    @c_loadkey NVARCHAR(10)
 )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 Declare @c_orderkey NVARCHAR(10),
         @c_externorderkey NVARCHAR(50),  --tlting_ext
         @c_buyerpo NVARCHAR(20)

 Declare @c_ordkey NVARCHAR(255),
         @c_externordkey NVARCHAR(255),
         @c_buypo NVARCHAR(225)

 set @c_ordkey = "*"
 set @c_orderkey = ""
 set @c_externordkey = "*"
 set @c_externorderkey = ""
 set @c_buypo = "*"
 set @c_buyerpo = ""

 Declare cur5 cursor FAST_FORWARD READ_ONLY
 For
 SELECT Orderkey, ExternOrderkey, BuyerPO FROM ORDERS (NOLOCK)
 WHERE Loadkey = @c_loadkey
 ORDER BY  Orderkey
 OPEN cur5
 Fetch Next From cur5 into @c_orderkey, @c_externorderkey, @c_buyerpo
 While (@@fetch_status=0)
   BEGIN
 	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ordkey)) <> '' AND (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ordkey)) <> '*')
 		SELECT @c_ordkey = @c_ordkey + ' / '
        SET @c_ordkey = @c_ordkey + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_orderkey))
       
      SELECT @c_externordkey = @c_externordkey + ' / '
         SET @c_externordkey = @c_externordkey + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_externorderkey))

      SELECT @c_buypo = @c_buypo + ' / '
         SET @c_buypo = @c_buypo + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_buyerpo))

       Fetch Next From cur5 into @c_orderkey, @c_externorderkey, @c_buyerpo
    END
 Close cur5
 Deallocate cur5
 SELECT Left(@c_ordkey, 255), LEFT(@c_externordkey,255), LEFT(@c_buypo,255)
 END

GO