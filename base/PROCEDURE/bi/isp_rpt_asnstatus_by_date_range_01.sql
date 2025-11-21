SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_ASNStatus_by_Date_Range_01                    */
/* Creation: 4/5/2024 by MMA982                                            */
/* Copyright: Maersk CE EUR                                                */
/*                                                                         */
/*                                                                         */
/* Purpose: https://maersk-tools.atlassian.net/browse/WCEET-1900           */
/*                                                                         */
/* GitHub Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date Author Ver Purposes                                                */
/*                                                                         */
/***************************************************************************/
CREATE
  PROC [BI].[isp_RPT_ASNStatus_by_Date_Range_01] @StorerKey varchar
(15) , @startdate date , @enddate date
AS
BEGIN
SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF
select 
rc.Facility as 'Facility',
rc.StorerKey AS 'Storer',
rc.ReceiptKey as 'ASN WMS Number',
rc.ExternReceiptKey'ASN Ext Number',
CASE 
			WHEN rc.STATUS = 9
				THEN 'Received'
			ELSE 'Not Fully Received'
			END AS 'Receiving Status',
CASE 
			WHEN rc.ASNStatus = '0'
				THEN 'Open'
			WHEN rc.ASNStatus = '9'
				THEN 'Closed'
			WHEN rc.ASNStatus = 'CANC'
				THEN 'Canceled'
			ELSE 'In Process'
			END AS 'ASN Status',
format(rc.FinalizeDate, N'dd-MM-yyyy hh:mm tt') as
ReceiptDate,
rc.ContainerKey as Container
from receipt rc WITH (NOLOCK)
where rc.StorerKey = @StorerKey
and rc.FinalizeDate >= REPLACE(ISNULL(@startdate,''),'','')
and rc.FinalizeDate <= REPLACE(ISNULL(DATEADD(DAY, 1,
@enddate),''),'','')
and rc.DOCTYPE = 'A'
order by rc.ReceiptKey desc
END

GO