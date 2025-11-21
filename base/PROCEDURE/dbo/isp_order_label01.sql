SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_Order_Label01                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print order label with poison flag                          */
/*                                                                      */
/* Called from: r_dw_order_label01                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-Feb-2009 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [dbo].[isp_Order_Label01] 
   @c_OrderKey NVARCHAR( 10)
AS
BEGIN
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @c_PoisonFlag NVARCHAR( 30),
      @c_SKUPoisonFlag   NVARCHAR( 30),
      @n_Firsttime       INT

   SET @c_PoisonFlag = ''
   SET @c_SKUPoisonFlag = ''
   SET @n_Firsttime = 0
   -- Get the poison flag
   -- Need to do in 2 steps coz HK want to concatenate 2 poison flag if exists
   DECLARE CUR_PoisonFlag CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT SKU.BUSR8 FROM OrderDetail OD WITH (NOLOCK) 
   JOIN SKU SKU WITH (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND OD.SKU = SKU.SKU)
   WHERE OrderKey = @c_orderkey
   OPEN CUR_PoisonFlag
   FETCH NEXT FROM CUR_PoisonFlag INTO @c_SKUPoisonFlag
   WHILE @@FETCH_STATUS <> '-1'
   BEGIN
      IF @n_Firsttime = 0
      BEGIN
         SELECT @c_PoisonFlag = RTRIM(@c_SKUPoisonFlag) 
         SET @n_Firsttime = 1
      END
      ELSE
         SELECT @c_PoisonFlag = RTRIM(@c_PoisonFlag) + ', ' + RTRIM(@c_SKUPoisonFlag) 

      FETCH NEXT FROM CUR_PoisonFlag INTO @c_SKUPoisonFlag
   END
   CLOSE CUR_PoisonFlag
   DEALLOCATE CUR_PoisonFlag

   SELECT 
      STORER.Company AS Company,
      ORDERS.StorerKey AS StorerKey,
      ORDERS.OrderKey AS OrderKey,
      ORDERS.ExternOrderKey AS ExternOrderKey,
      ORDERS.ConsigneeKey AS ConsigneeKey,
      ORDERS.C_Company AS C_Company,
      ORDERS.C_address1 AS C_address1,
      ORDERS.C_address2 AS C_address2,
      ORDERS.C_address3 AS C_address3,
      ORDERS.C_address4 AS C_address4,
      CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2,  '')) AS Notes2,
      ORDERS.Route AS Route,
      ORDERS.UserDefine09 AS UserDefine09,
      ORDERS.Deliverydate AS Deliverydate,
      ORDERS.Pmtterm AS Pmtterm,
      @c_PoisonFlag,
      SUM(PICKDETAIL.Qty) AS QTY
	FROM  ORDERS WITH (NOLOCK)   
	JOIN	PICKDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey)
   JOIN  STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
--   JOIN  SKU WITH (NOLOCK) ON (PICKDETAIL.SKU = SKU.SKU)
	WHERE ORDERS.OrderKey = @c_orderkey
	GROUP BY
         STORER.Company,
			ORDERS.StorerKey,
			ORDERS.OrderKey,
			ORDERS.ExternOrderKey,
			ORDERS.ConsigneeKey,
			ORDERS.C_Company,
			ORDERS.C_address1,
			ORDERS.C_address2,
			ORDERS.C_address3,
			ORDERS.C_address4,
			CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')),
			ORDERS.Route,
			ORDERS.UserDefine09,
			ORDERS.Deliverydate,
			ORDERS.Pmtterm
END

GO