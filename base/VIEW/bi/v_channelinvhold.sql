SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* View: BI.V_ChannelInvHold                                               */
/* https://jiralfl.atlassian.net/browse/WMS-17256                          */
/* Creation Date: 11-Jun-2021                                              */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 11-Jun-2021  ZiWei    1.0   Created                                     */
/***************************************************************************/

CREATE   VIEW [BI].[V_ChannelInvHold] 
AS SELECT * FROM ChannelInvHold WITH (NOLOCK)

GO