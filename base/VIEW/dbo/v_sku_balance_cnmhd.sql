SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_SKU_BALANCE_CNMHD]
AS

SELECT SKU.StorerKey,
       SKU.BUSR6 'Brands',
       SKU.SKUGroup 'Category',
       SKU.SKU,
       SKU.DESCR,
       SKU.BUSR3,
       SKU.BUSR10,
       CASE WHEN ISNULL(RTRIM(Substring(BUSR4, 34,5)),'') <> ''
            THEN 'img'
            else 'noimg'
       END As Images,
       CASE WHEN ISNULL(RTRIM(Substring(BUSR4, 34,5)),'') <> ''
            THEN 'https' + '://ewms.lfuat.net/IMG/'
                  + C.Short +'/'+ ISNULL(RTRIM(SKU.StorerKey),'') + '/' + RTRIM(Substring(BUSR4, 34,5))
                  + '/' + RTRIM(SKU.SKU) + '.JPG'
            else RTRIM(C.Long) + RTRIM(C.Short) + RTRIM(C.Notes)
       END As ImagePath
FROM SKU WITH (NOLOCK)
JOIN CODELKUP C WITH (NOLOCK) ON C.Listname = 'eWMSCtry'
JOIN V_LOTxLOCxID LLI ON LLI.SKU = SKU.SKU and LLI.StorerKey = SKU.StorerKey
JOIN LOC (NOLOCK) LOC ON LOC.LOC = LLI.LOC AND LOC.LocationFlag <> 'DAMAGE'
JOIN Lotattribute (NOLOCK) Lotattribute ON Lotattribute.Lot = LLI.Lot
WHERE sku.storerkey ='18503'
group by SKU.StorerKey, SKU.BUSR6, SKU.SKUGroup, SKU.SKU, SKU.DESCR, SKU.BUSR3, SKU.BUSR10, BUSR4,
         c.Short, c.Long, c.Notes
Having sum(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) - (case when len(SKU.BUSR10) = 0 AND SKU.BUSR10='' then 0   -- if BUSR ='' and available qty - 0 > 0
                                                               WHEN len(SKU.BUSR10) > 0 AND ISNUMERIC(SKU.BUSR10)=1 THEN SKU.BUSR10    --if BUSR10 is numeric and available qty - busr10 > 0
                                                               end)  > 0










GO