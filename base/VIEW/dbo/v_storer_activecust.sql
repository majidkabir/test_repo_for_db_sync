SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE   VIEW [dbo].[V_STORER_ActiveCust]
AS
SELECT DbName = DB_NAME()
   , S.StorerKey
   , S.Company
   , S.CustomerGroupCode
   , S.CustomerGroupName
   , S.[Status]
   , S.AddDate
   , S.EditDate
   , SumInvQty
   , ItrnCount
   , ItrnAddDate
FROM dbo.Storer AS S WITH (NOLOCK)
OUTER APPLY (  SELECT SumInvQty = SUM(CAST(L.Qty AS bigint)) 
               FROM LOTxLOCxID L WITH (NOLOCK)
               WHERE L.StorerKey = S.StorerKey
               GROUP BY L.StorerKey ) AS l

OUTER APPLY (  SELECT ItrnCount = COUNT(I.ItrnKey), ItrnAddDate = MAX(AddDate) 
               FROM ITRN AS I WITH (NOLOCK)
               WHERE I.StorerKey = S.StorerKey ) AS p
WHERE S.[Type] = '1'
AND ISNULL(TRIM(S.[Status]),'') NOT IN ('INACTIVE','0')


GO