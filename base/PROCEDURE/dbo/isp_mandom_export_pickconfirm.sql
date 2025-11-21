SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_mandom_export_pickconfirm]
AS
   SET CONCAT_NULL_YIELDS_NULL OFF
-- insert candidate records into table 
BEGIN
   
	DECLARE @cKey NVARCHAR(10),
           @c_lines   int,
           @b_success int,
           @cHeaderID NVARCHAR(15),
           @n_err     int, 
           @c_errmsg  NVARCHAR(255), 
           @c_picklineno NVARCHAR(10), 
           @cStorerkey NVARCHAR(15)

   SELECT @cStorerkey = 'MANDOM'

	select @ckey = ''
	WHILE (1 = 1)
   BEGIN
      SELECT @cKey = MIN(Key1)
      FROM Transmitlog2 (NOLOCK)
      JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = Transmitlog2.Key1
                              AND ORDERS.Storerkey = @cStorerkey)
      WHERE Transmitflag = '1'
      AND Tablename = 'MDMMYPICK'
      AND Key1 > @cKey
   
      IF @@ROWCOUNT= 0 or @cKey is null
		   BREAK

		-- insert order header
		IF NOT EXISTS (SELECT 1 FROM DTSITF..MANDOMPICK (NOLOCK) WHERE ORDERKEY = @CKEY )
      BEGIN
         INSERT INTO DTSITF..MANDOMPICK (ORDERKEY, EXTERNORDERKEY, EXTERNLINENO, SKU, QTYPICKED, UOM)
         SELECT ORDERKEY, EXTERNORDERKEY, EXTERNLINENO, SKU, 
               CASE 
                  WHEN OrderDetail.UOM = Pack.PackUOM1 THEN (OrderDetail.QTYPICKED + ORDERDETAIL.SHIPPEDQTY) / Pack.CaseCnt
                  WHEN OrderDetail.UOM = Pack.PackUOM2 THEN (OrderDetail.QTYPICKED + ORDERDETAIL.SHIPPEDQTY) / Pack.InnerPacK
                  WHEN OrderDetail.UOM = Pack.PackUOM3 THEN (OrderDetail.QTYPICKED + ORDERDETAIL.SHIPPEDQTY) / Pack.Qty
                  WHEN OrderDetail.UOM = Pack.PackUOM4 THEN (OrderDetail.QTYPICKED + ORDERDETAIL.SHIPPEDQTY) / Pack.Pallet  
                  ELSE 0
               END, ORDERDETAIL.UOM
         FROM ORDERDETAIL (NOLOCK)
         INNER JOIN PACK (NOLOCK) ON (PACK.PACKKEY = ORDERDETAIL.PACKKEY)
         WHERE STORERKEY = @CSTORERKEY
         AND ORDERKEY = @CKEY
      END         
	END -- WHILE (1 = 1)
end -- END PROC

GO