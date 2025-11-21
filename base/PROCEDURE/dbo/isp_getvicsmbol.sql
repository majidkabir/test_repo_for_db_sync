SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: isp_GetVicsMbol                                                  */
/* Creation Date: 18-Jun-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: UWP-20706 - Granite | MWMS | BOL Report (FCR-234)           */
/*        :                                                             */
/* Called By: Ported from PB function - f_get_vics_mbol                 */
/*          :                                                           */
/* Github Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 18-Jun-2024 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_GetVicsMbol]
(
   @c_Mbolkey NVARCHAR(10)
 , @c_Vics_MBOL NVARCHAR(60) OUTPUT
)
AS
BEGIN
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF

   DECLARE @c_ExternMBOLKey NVARCHAR(60)
         , @c_UCC           NVARCHAR(50)
         , @n_length        INT = 0
         , @n_count         INT = 0
         , @n_odd           INT = 0
         , @n_even          INT = 0
         , @n_check_digit   INT = 0
         , @n_len           INT = 0

   DECLARE @c_Facility                NVARCHAR(5)
         , @c_Storerkey               NVARCHAR(15)
         , @c_vicbillnumber_authority NVARCHAR(50) = N''
         , @c_Startnumber             NVARCHAR(50)
         , @c_Endnumber               NVARCHAR(50)
         , @c_Keyname                 NVARCHAR(50)
         , @c_Keystring               NVARCHAR(50)
         , @c_PartialSSCC             NVARCHAR(17)
         , @n_Startnumber             INT          = 0
         , @n_Endnumber               INT          = 0
         , @n_Runnolen                INT          = 0
         , @n_SumAll                  INT          = 0
         , @c_ExistUCC                NVARCHAR(50) = ''

   DECLARE @b_Success   INT
         , @c_authority NVARCHAR(30) = N''
         , @n_err       INT
         , @c_errmsg    NVARCHAR(250)

   SELECT @c_ExternMBOLKey = ExternMbolKey
        , @c_Facility = Facility
   FROM MBOL WITH (NOLOCK)
   WHERE MbolKey = @c_Mbolkey

   IF ISNULL(@c_ExternMBOLKey, '') = ''
      SET @c_ExternMBOLKey = N''

   IF @c_ExternMBOLKey = ''
   BEGIN
      SELECT @c_UCC = MAX(STORER.SUSR5)
           , @c_Storerkey = MAX(STORER.StorerKey)
      FROM MBOLDETAIL WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      JOIN STORER WITH (NOLOCK) ON (STORER.StorerKey = ORDERS.StorerKey)
      WHERE MBOLDETAIL.MbolKey = @c_Mbolkey

      IF ISNULL(@c_UCC, '') = '' OR LEN(TRIM(@c_UCC)) = 0
      BEGIN
         SET @c_Vics_MBOL = ''
         GOTO QUIT_SP
      END
      ELSE
      BEGIN
         SET @c_ExistUCC = @c_UCC
         SET @c_UCC = SUBSTRING(@c_UCC, PATINDEX('%[^0]%', @c_UCC), LEN(@c_UCC))   --Remove leading zero

         IF ISNULL(@c_UCC, '') = ''
         BEGIN
            SET @c_UCC = @c_ExistUCC
         END
      END

      IF ISNUMERIC(@c_UCC) = 0
      BEGIN
         SET @c_Vics_MBOL = ''
         GOTO QUIT_SP
      END

      SET @c_Vics_MBOL = TRIM(@c_UCC) + RIGHT(TRIM(@c_Mbolkey), 8)
      SET @c_PartialSSCC = @c_Vics_MBOL
      SET @n_length = LEN(@c_PartialSSCC)

      IF @n_length > 0
      BEGIN
         SET @n_count = 1

         WHILE (@n_count <= @n_length)
         BEGIN
            IF @n_count % 2 > 0
               SET @n_odd = @n_odd + CAST(SUBSTRING(@c_PartialSSCC, @n_count, 1) AS INT) --ADD all digit in Odd Placement
            ELSE
               SET @n_even = @n_even + CAST(SUBSTRING(@c_PartialSSCC, @n_count, 1) AS INT) --ADD all digit in Even Placement

            SET @n_count = @n_count + 1
         END
      END

      SET @n_SumAll = (@n_odd * 3) + @n_even

      SET @n_check_digit = CONVERT(NVARCHAR(1),(1000 - @n_SumAll) % 10)

      SET @c_Vics_MBOL = @c_Vics_MBOL + CAST(@n_check_digit AS NVARCHAR)
   END
   ELSE
   BEGIN
      SET @c_Vics_MBOL = @c_ExternMBOLKey
   END

   QUIT_SP:
END -- procedure

GO