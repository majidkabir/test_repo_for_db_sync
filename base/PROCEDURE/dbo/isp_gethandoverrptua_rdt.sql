SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetHandoverRptUA_RDT                                */
/* Creation Date: 11-March-2022                                         */
/* Copyright: LF Logistics                                              */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-19111 - UA Handover Report                              */
/*        :                                                             */
/* Called By: r_dw_handover_rpt_ua_rdt                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 16-Mar-2022 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_GetHandoverRptUA_RDT]
         @c_Sourcekey      NVARCHAR(50)
             
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   SELECT AL1.MbolKey, MBOL.ExternMbolKey, ISNULL(CD.Notes,'') AS Notes, AL3.TrackingNo, AL1.OrderKey,
          CASE WHEN AL1.CtnCnt1 > 0 AND 
                    (AL1.CtnCnt2 + AL1.CtnCnt3 + AL1.CtnCnt4 + AL1.CtnCnt5) = 0 THEN 'CTN1'
               WHEN AL1.CtnCnt2 > 0 AND 
                    (AL1.CtnCnt1 + AL1.CtnCnt3 + AL1.CtnCnt4 + AL1.CtnCnt5) = 0 THEN 'CTN2'
               WHEN AL1.CtnCnt3 > 0 AND 
                    (AL1.CtnCnt2 + AL1.CtnCnt1 + AL1.CtnCnt4 + AL1.CtnCnt5) = 0 THEN 'CTN3'
               WHEN AL1.CtnCnt4 > 0 AND 
                    (AL1.CtnCnt2 + AL1.CtnCnt3 + AL1.CtnCnt1 + AL1.CtnCnt5) = 0 THEN 'CTN4'
               WHEN AL1.CtnCnt5 > 0 AND 
                    (AL1.CtnCnt2 + AL1.CtnCnt3 + AL1.CtnCnt4 + AL1.CtnCnt1) = 0 THEN 'CTN5'
               ELSE 'Multiple CTN' END AS CtnNo,
          CASE WHEN AL1.CtnCnt1 > 0 AND 
                    AL1.CtnCnt2 + AL1.CtnCnt3 + AL1.CtnCnt4 + AL1.CtnCnt5 = 0 THEN AL1.Ctncnt1
               WHEN AL1.CtnCnt2 > 0 AND 
                    AL1.CtnCnt1 + AL1.CtnCnt3 + AL1.CtnCnt4 + AL1.CtnCnt5 = 0 THEN AL1.Ctncnt2
               WHEN AL1.CtnCnt3 > 0 AND 
                    AL1.CtnCnt2 + AL1.CtnCnt1 + AL1.CtnCnt4 + AL1.CtnCnt5 = 0 THEN AL1.Ctncnt3
               WHEN AL1.CtnCnt4 > 0 AND 
                    AL1.CtnCnt2 + AL1.CtnCnt3 + AL1.CtnCnt1 + AL1.CtnCnt5 = 0 THEN AL1.Ctncnt4
               WHEN AL1.CtnCnt5 > 0 AND 
                    AL1.CtnCnt2 + AL1.CtnCnt3 + AL1.CtnCnt4 + AL1.CtnCnt1 = 0 THEN AL1.Ctncnt5
               ELSE AL1.Ctncnt1 + AL1.Ctncnt2 + AL1.Ctncnt3 + AL1.Ctncnt4 + AL1.Ctncnt5 END AS CtnCnt
   FROM MBOL (NOLOCK)
   JOIN MBOLDETAIL AL1 (NOLOCK) ON MBOL.MbolKey = AL1.MbolKey
   JOIN ORDERS AL3 (NOLOCK) ON AL1.OrderKey = AL3.OrderKey
   LEFT JOIN CODELKUP CD (NOLOCK) ON (CD.listname = 'UAHOL' AND CD.Code = AL3.shipperkey 
                                  AND CD.Storerkey = AL3.Storerkey) 
   WHERE MBOL.ExternMbolKey = @c_Sourcekey
   ORDER BY AL3.TrackingNo, AL1.OrderKey

QUIT_SP:
END -- procedure

GO