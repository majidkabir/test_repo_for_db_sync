SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE   PROCEDURE [dbo].[isp_RPT_CB_VICSCBOL_EmptyTest]
(
   @n_Cbolkey  BIGINT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT = 1
         , @n_StartTCnt INT = @@TRANCOUNT
         , @n_ResultSize INT = 0

   SELECT @n_ResultSize = COUNT(*)
   FROM CBOL WITH (NOLOCK)
   JOIN MBOL  WITH (NOLOCK) ON (CBOL.Cbolkey = MBOL.Cbolkey)
   JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey )
   JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
   WHERE CBOL.CbolKey = @n_Cbolkey 
   AND ORDERS.[Status] >= '5'

    IF @n_ResultSize = 0 RAISERROR('No records found', 16, 1)

   SELECT DISTINCT CBOL.CbolKey
                 , DepartureDate = [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, MBOL.Facility, GETDATE())   --WL01
   FROM CBOL WITH (NOLOCK)
   JOIN MBOL  WITH (NOLOCK) ON (CBOL.Cbolkey = MBOL.Cbolkey)
   JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey )
   JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
   WHERE CBOL.CbolKey = @n_Cbolkey 
   AND ORDERS.[Status] >= '5'
END -- procedure
GO