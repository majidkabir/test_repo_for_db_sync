SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function       : fnc_BOM_UOM                                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: To Split the Value in the String And Return as Column       */
/*          From Table.                                                 */
/*                                                                      */
/* Usage: SELECT * from dbo.fnc_BOM_UOM (StorerKey, BOM_SKU)            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2010-04-29   1.0  SHONG    Created                                   */
/* 2014-03-21   1.1  TLTING   SQL2012 Bug fix                           */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_BOM_UOM]
(
    @c_StorerKey   NVARCHAR(15)
   ,@c_BOM_SKU     NVARCHAR(20)
)
RETURNS TABLE
AS
RETURN (
    WITH Result1 (Storerkey, Sku, ComponentSku, Qty, IP_PackKey, IP_UOM, IP_Qty, CS_UOM, CS_Qty) AS (
      SELECT BOM.Storerkey
            ,BOM.Sku
            ,BOM.ComponentSku
            ,BOM.Qty
            ,UPC.PackKey AS ippackkey
            ,PACK1.PackUOM2 AS IPUOM
            ,ISNULL(PACK1.InnerPack ,1) AS IPQTY
            ,PACK1.PackUOM1 AS CSUOM
            ,ISNULL(PACK2.CaseCnt ,1) AS CSQTY
      FROM   dbo.BillOfMaterial AS BOM WITH (NOLOCK)
      LEFT OUTER JOIN dbo.UPC AS UPC WITH (NOLOCK) ON  BOM.Storerkey = UPC.StorerKey 
                                                  AND  BOM.Sku = UPC.SKU
                                                  AND  UPC.UOM = 'IP'
      LEFT OUTER JOIN dbo.PACK AS PACK1 WITH (NOLOCK) ON  UPC.PackKey = PACK1.PackKey
      LEFT OUTER JOIN dbo.UPC  AS UPC2  WITH (NOLOCK) ON  BOM.Storerkey = UPC2.StorerKey
                                                     AND  BOM.Sku = UPC2.SKU
                                                     AND  UPC2.UOM = 'CS'
      LEFT OUTER JOIN dbo.PACK AS PACK2 WITH (NOLOCK) ON  UPC2.PackKey = PACK2.PackKey 
      WHERE BOM.Storerkey = @c_StorerKey 
      AND   BOM.Sku = @c_BOM_SKU 

    )
    SELECT Storerkey, Sku, ComponentSku, Qty, IP_PackKey, IP_UOM, IP_Qty, CS_UOM, CS_Qty 
    FROM Result1
  )

GO