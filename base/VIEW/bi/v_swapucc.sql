SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Purpose: [PH] - Create BI View RDT.SwapUCC                              */
/* https://jiralfl.atlassian.net/browse/WMS-21858                          */
/* Creation Date: 06-MAR-2023                                              */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author		 Ver.  Purposes                                 */
/* 06-MAR-2023  ZiWei       1.0   Created                                  */
/***************************************************************************/

CREATE VIEW [BI].[V_SWAPUCC]  AS  
SELECT *
FROM rdt.[SwapUCC] (NOLOCK)  


GO