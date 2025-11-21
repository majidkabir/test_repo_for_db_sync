SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Stored Procedure: isp_RPT_WV_WAVPICKSUM_004_1                           */      
/* Creation Date: 16-NOV-2022                                              */      
/* Copyright: LFL                                                          */      
/* Written by: WZPang                                                      */      
/*                                                                         */      
/* Purpose: WMS-21095 - TW-NIK WM Report_WAVPICKSUM - CR                   */      
/*                                                                         */      
/* Called By: RPT_WV_WAVPICKSUM_004_1                                      */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 16-NOV-2022  WZPang  1.0   DevOps Combine Script                        */  
/***************************************************************************/  
CREATE   PROC [dbo].[isp_RPT_WV_WAVPICKSUM_004_1](  
      @c_Wavekey           NVARCHAR(10)
      )
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF
   
	SELECT L.LocationCategory
		,	COUNT(DISTINCT(L.Loc)) AS 'LocationCount'
		,	SUM(PICKDETAIL.Qty) AS WaveKeyTotal
	FROM	PICKDETAIL (NOLOCK)
	JOIN	LOC (NOLOCK) L ON (PICKDETAIL.Loc = L.Loc)
	JOIN	ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)
	WHERE	ORDERS.UserDefine09 = @c_Wavekey
	GROUP BY L.LocationCategory

END -- procedure   

GO