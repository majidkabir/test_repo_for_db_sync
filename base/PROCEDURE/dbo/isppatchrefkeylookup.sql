SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispPatchRefKeyLookup                                */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: - Patch missing RefKeyLookup to meet isp_ArchivePicknPack   */
/*            requirement.                                              */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author    Ver.  Purposes                                */
/* 31-Oct-2016  Leong     1.0   IN00162892 - Created.                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPatchRefKeyLookup]
     @c_StorerKey  NVARCHAR(15)
   , @c_Zone       NVARCHAR(18)
   , @n_Days       INT = 2
   , @b_debug      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_OrderKey   NVARCHAR(10)
         , @c_LoadKey    NVARCHAR(10)
         , @c_PickSlipNo NVARCHAR(18)
         , @n_Counter    INT

   SET @n_Counter = 1

   DECLARE CUR_RefKeyLookup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.LoadKey, O.OrderKey
      FROM Orders O WITH (NOLOCK)
      WHERE O.StorerKey = @c_StorerKey
      AND ISNULL(RTRIM(O.LoadKey),'') <> ''
      AND O.Status = '9'
      AND DATEDIFF(Day, O.EditDate, GETDATE()) >= @n_Days
      AND NOT EXISTS (SELECT 1 FROM RefKeyLookUp R WITH (NOLOCK)
                      WHERE R.OrderKey = O.OrderKey)
      ORDER BY O.OrderKey

   OPEN CUR_RefKeyLookup
   FETCH NEXT FROM CUR_RefKeyLookup INTO @c_LoadKey, @c_OrderKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      BEGIN TRAN

      SET @c_PickSlipNo = ''
      SELECT @c_PickSlipNo = PickHeaderKey
      FROM PickHeader WITH (NOLOCK)
      WHERE Zone = @c_Zone
      AND ExternOrderKey = @c_LoadKey

      IF ISNULL(RTRIM(@c_PickSlipNo),'') <> ''
         AND EXISTS (SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM RefKeyLookUp WITH (NOLOCK) WHERE OrderKey = @c_OrderKey)
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_LoadKey '@c_LoadKey', @c_OrderKey '@c_OrderKey', @c_PickSlipNo '@c_PickSlipNo', @n_Counter '@n_Counter'
            END

            INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho, EditDate)
            SELECT PickDetailkey, @c_PickSlipNo, OrderKey, OrderLineNumber, @c_LoadKey, 'BejTask', GETDATE()
            FROM PickDetail WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey

            SET @n_Counter = @n_Counter + 1
         END
      END

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         BREAK
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END

      FETCH NEXT FROM CUR_RefKeyLookup INTO @c_LoadKey, @c_OrderKey
   END
   CLOSE CUR_RefKeyLookup
   DEALLOCATE CUR_RefKeyLookup
END -- Procedure

GO