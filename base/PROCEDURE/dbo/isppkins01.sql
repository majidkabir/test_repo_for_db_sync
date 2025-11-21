SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPKINS01                                          */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: SOS#320446 - SG Prestige- get sku pack instruction          */
/*                                                                      */
/* Called from: isp_PackGetInstruction_Wrapper                          */
/*              storerconfig: PackGetInstruction_SP                     */
/*                                                                      */
/* Exceed version: 7.0                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 15-SEP-2016 1.0  NJOW01     WMS-368 Change externorderkey extract    */
/*                             condition from SOR to SO                 */
/* 12-JAN-2017 1.1  Wan01      WMS-929 - Prestige SG - Scan Pack        */
/* 01-JUL-2021 1.2  NJOW02     WMS-17290 - Increase c_PackInstruction to*/
/*                             500                                      */
/* 17-Feb-2022 1.3  WLChooi    DevOps Combine Script                    */
/* 17-Feb-2022 1.3  WLChooi    WMS-18938 Modify logic to show GMR (WL01)*/
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPKINS01]
   @c_Pickslipno       NVARCHAR(10),
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(50),
   @c_PackInstruction  NVARCHAR(500) OUTPUT,  --NJOW02
   @b_Success          INT      OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_OVAS NVARCHAR(30)
         , @c_Country NVARCHAR(50)        --WL01
         , @c_OHCountry NVARCHAR(250)     --WL01
         , @c_ISOCntryCode NVARCHAR(250)  --WL01
                                 
   SELECT @b_Success = 1, @n_ErrNo = 0, @c_ErrMsg = '', @c_PackInstruction = '', @c_OVAS = ''  
    
   --(Wan01) - START
   SET @c_PackInstruction = ISNULL(RTRIM(@c_PackInstruction),'')
   IF EXISTS (SELECT 1
              FROM PICKHEADER (NOLOCK)
              JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.OrderKey
              JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
              JOIN STORER (NOLOCK) ON ORDERS.ConsigneeKey = STORER.Storerkey
              JOIN SKU (NOLOCK) ON ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku
              WHERE PICKHEADER.PickHeaderKey = @c_Pickslipno
              AND ORDERDETAIL.Sku = @c_Sku  
              AND ORDERDETAIL.Storerkey = @c_Storerkey 
              AND STORER.SUSR4 = 'SECURITY TAG' 
              AND STORER.Type = '2'                   --(Wan01)
              AND SKU.Price >= 50)

   BEGIN
      IF CHARINDEX('S.TAG', @c_PackInstruction) = 0
      BEGIN
         IF RTRIM(@c_PackInstruction) <> ''
         BEGIN
            SET @c_PackInstruction = @c_PackInstruction + ', '
         END 
         SET @c_PackInstruction = @c_PackInstruction + 'S.TAG'
      END
   END

   --WL01 S
   SELECT @c_Country = N.NSQLValue
   FROM NSQLCONFIG N (NOLOCK)
   WHERE N.ConfigKey = 'Country'

   IF @c_Country = 'MY'
   BEGIN
      SELECT TOP 1 @c_OHCountry = Long
      FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'PRESCONFIG'
      AND Code = 'GMR'
      AND code2 = 'Country'
      AND Storerkey = @c_Storerkey

      SELECT TOP 1 @c_ISOCntryCode = Long
      FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'PRESCONFIG'
      AND Code = 'GMR'
      AND code2 = 'ISOCntryCode'
      AND Storerkey = @c_Storerkey

      IF EXISTS ( 
                  SELECT 1
                  FROM PICKHEADER (NOLOCK)
                  JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.OrderKey
                  JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
                  JOIN STORER (NOLOCK) ON ORDERS.ConsigneeKey = STORER.Storerkey
                  JOIN SKU (NOLOCK) ON ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku
                  WHERE PICKHEADER.PickHeaderKey = @c_Pickslipno
                  AND ORDERDETAIL.Sku = @c_Sku  
                  AND ORDERDETAIL.Storerkey = @c_Storerkey
                  AND STORER.Country IN (SELECT DISTINCT ColValue 
                                         FROM dbo.fnc_DelimSplit(',', @c_Country) FDS)
                  AND STORER.ISOCntryCode IN (SELECT DISTINCT ColValue 
                                              FROM dbo.fnc_DelimSplit(',', @c_ISOCntryCode) FDS)
                  AND STORER.Type = '2'
                  AND SKU.OVAS = 'GMR'
                  )
      BEGIN      
         IF CHARINDEX('GMR', @c_PackInstruction) = 0
         BEGIN
            IF RTRIM(@c_PackInstruction) <> ''
            BEGIN
               SET @c_PackInstruction = @c_PackInstruction + ', '
            END 
            SET @c_PackInstruction = @c_PackInstruction + 'GMR'
         END
      END 
   END
   ELSE
   BEGIN
   --WL01 E
      IF EXISTS ( 
                  SELECT 1 -- @c_OVAS = SKU.OVAS         --(Wan01)
                  FROM PICKHEADER (NOLOCK)
                  JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.OrderKey
                  JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
                  JOIN STORER (NOLOCK) ON ORDERS.ConsigneeKey = STORER.Storerkey
                  JOIN SKU (NOLOCK) ON ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku
                  WHERE PICKHEADER.PickHeaderKey = @c_Pickslipno
                  AND ORDERDETAIL.Sku = @c_Sku  
                  AND ORDERDETAIL.Storerkey = @c_Storerkey
                  --AND LEFT(LTRIM(ORDERS.ExternOrderkey), 2) = 'SO' --NJOW01 --(Wan01)
                  AND STORER.Country = 'SG' 
                  AND STORER.ISOCntryCode = 'SG'
                  AND STORER.Type = '2'                  --(Wan01)
                  AND SKU.OVAS = 'GMR'                   --(Wan01)
                  )
      BEGIN      
            --IF ISNULL(@c_OVAS,'') <> ''
            --   SET @c_PackInstruction = 'S.TAG,' + LTRIM(RTRIM(@c_OVAS))
            --ELSE
            --   SET @c_PackInstruction = 'S.TAG'
         IF CHARINDEX('GMR', @c_PackInstruction) = 0
         BEGIN
            IF RTRIM(@c_PackInstruction) <> ''
            BEGIN
               SET @c_PackInstruction = @c_PackInstruction + ', '
            END 
            SET @c_PackInstruction = @c_PackInstruction + 'GMR'
         END
      END     
      --(Wan01) - END   
   END   --WL01
END -- End Procedure


GO