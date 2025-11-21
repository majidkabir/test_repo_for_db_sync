SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_nikecn_ConsoDespatchTkt4								*/
/* Creation Date: 25-APR-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: NIKE CN - Display ExternOrderkey for Conso. Despatch Ticket */
/*                                                                      */
/* Called By: r_dw_despatch_ticket_nikecn4                              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 03-Dec-2007  James      SOS#88823 - Modified from                    */
/*                         isp_nikecn_ConsoDespatchTkt                  */
/* 03-Dec-2007  James      SOS#85868 - Add in 2 additional parameters   */
/*                         startcartonno & endcartonno                  */  
/* 21-Aug-2008  Shong      Add Location Aisle                           */ 
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */     
/************************************************************************/

CREATE PROC [dbo].[isp_nikecn_ConsoDespatchTkt4]
	@c_WaveKey 		 NVARCHAR( 10),		--compulsary
	@n_StartCartonNo 	INT = 0,			--optional
	@n_EndCartonNo 	INT = 0,			--optional
	@c_StartAisle 	 NVARCHAR( 10) = '',--optional
	@c_EndAisle 	 NVARCHAR( 10) = '',--optional
	@c_StartLocLevel  NVARCHAR( 10) = '',--optional	(put char instead of int coz loclevel could be 0 also. cannot default to 0)
	@c_EndLocLevel  NVARCHAR( 10) = ''	--optional
	
AS
BEGIN

	SET NOCOUNT ON 
	SET QUOTED_IDENTIFIER OFF 
	SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF    

  DECLARE @c_externOrderkey  NVARCHAR( 50)	 --tlting_ext
		  , @c_Loadkey 		 NVARCHAR( 30)	
		  , @i_ExtCnt 				INT
		  , @i_LineCnt 			INT
		  , @SQL 				 NVARCHAR( 1000)
        , @c_pickslipno 	 NVARCHAR( 10)
        , @c_SQLStatement 		NVARCHAR( 4000)
		  , @n_StartLocLevel    INT
		  , @n_EndLocLevel		INT
		  
   CREATE TABLE #Result (
      [PickSlipNo]         [char] (10)  NULL , 
      [LoadKey]            [char] (10)  NULL , 
      [Route]              [char] (10)  NULL , 
      [ConsigneeKey]       [char] (15)  NULL , 
      [DeliveryDate]       [datetime]   NULL , 
      [C_Company]          [char] (45)  NULL , 
      [C_Address1]         [char] (45)  NULL , 
      [C_Address2]         [char] (45)  NULL , 
      [C_Address3]         [char] (45)  NULL , 
      [C_City]             [char] (45)  NULL , 
      [xDockLane]          [char] (10)  NULL , 
      [LabelNo]            [char] (10)  NULL , 
      [CartonNo]           [char] (20)  NULL , 
      [Loc]                [char] (10)  NULL , 
      [ExtOrder1]          [char] (80)  NULL , 
      [ExtOrder2]          [char] (80)  NULL , 
      [ExtOrder3]          [char] (80)  NULL , 
      [ExtOrder4]          [char] (80)  NULL , 
      [ExtOrder5]          [char] (80)  NULL , 
      [ExtOrder6]          [char] (80)  NULL , 
      [ExtOrder7]          [char] (80)  NULL , 
      [ExtOrder8]          [char] (80)  NULL , 
      [ExtOrder9]          [char] (80)  NULL , 
      [ExtOrder10]         [char] (80)  NULL , 
      [ExtOrder11]         [char] (80)  NULL , 
      [ExtOrder12]         [char] (80)  NULL , 
      [ExtOrder13]         [char] (80)  NULL , 
      [ExtOrder14]         [char] (80)  NULL , 
      [ExtOrder15]         [char] (80)  NULL , 
      [ExtOrder16]         [char] (80)  NULL , 
      [ExtOrder17]         [char] (80)  NULL , 
      [ExtOrder18]         [char] (80)  NULL , 
      [ExtOrder19]         [char] (80)  NULL , 
      [ExtOrder20]         [char] (80)  NULL ,            
      [TotalSku]           [int]        NULL , 
      [TotalPcs]           [int]        NULL ,
      [LocAisle]           [char] (10)  NULL, 
      [LocLevel]           [int]        NULL)

SELECT @c_SQLStatement = N'INSERT INTO #RESULT SELECT PackHeader.PickSlipNo, '
			+ 'PackHeader.LoadKey, '
			+ 'PackHeader.Route, '
			+ 'MAX(ORDERS.Consigneekey) as ConsigneeKey, '
			+ 'MAX(Orders.DeliveryDate) as DeliveryDate, '
			+ 'MAX(Orders.C_Company) as C_Company, '
 			+ 'MAX(Orders.C_Address1) as C_Address1, ' 
 			+ 'MAX(Orders.C_Address2) as C_Address2, '
 			+ 'MAX(Orders.C_Address3) as C_Address3, '
 			+ 'MAX(Orders.C_City) as C_City, '
			+ 'xDockLane = CASE WHEN MAX(ORDERS.xDockFlag) = ''1'' THEN '
			+ '				(SELECT StorerSODefault.xDockLane FROM StorerSODefault (NOLOCK) '
			+ '						 WHERE StorerSODefault.StorerKey = MAX(ORDERS.StorerKey)) '
			+ '					  ELSE SPACE(10) '
			+ '				END, '
			+ 'PackDetail.LabelNo, '
			+ 'PackDetail.CartonNo, '
			+ 'LOC.LOC, '
			+ 'ExtOrder1 = SPACE(80), '
			+ 'ExtOrder2 = SPACE(80), '
			+ 'ExtOrder3 = SPACE(80), '
			+ 'ExtOrder4 = SPACE(80), '
			+ 'ExtOrder5 = SPACE(80), '
			+ 'ExtOrder6 = SPACE(80), '
			+ 'ExtOrder7 = SPACE(80), '
			+ 'ExtOrder8 = SPACE(80), '
			+ 'ExtOrder9 = SPACE(80), '
			+ 'ExtOrder10 = SPACE(80), '
			+ 'ExtOrder11 = SPACE(80), '
			+ 'ExtOrder12 = SPACE(80), '
			+ 'ExtOrder13 = SPACE(80), '
			+ 'ExtOrder14 = SPACE(80), '
			+ 'ExtOrder15 = SPACE(80), '
			+ 'ExtOrder16 = SPACE(80), '
			+ 'ExtOrder17 = SPACE(80), '
			+ 'ExtOrder18 = SPACE(80), '
			+ 'ExtOrder19 = SPACE(80), '
			+ 'ExtOrder20 = SPACE(80), '						
         + 'COUNT(PACKDETAIL.Sku) AS TotalSku, '
         + 'SUM(PACKDETAIL.Qty) AS TotalPcs, '
         + 'LOC.LOCAISLE, ' -- -- Added By Shong on 21th Aug 2008
         + 'LOC.LocLevel '
         + 'FROM WaveDetail WITH (NOLOCK) '
         + 'JOIN Orders WITH (NOLOCK) ON (Orders.UserDefine09 = WaveDetail.WaveKey AND Orders.OrderKey = WaveDetail.OrderKey) '
         + 'JOIN LoadplanDetail WITH (NOLOCK) ON (Orders.OrderKey = LoadplanDetail.OrderKey) '
         + 'JOIN PackHeader WITH (NOLOCK) ON (LoadplanDetail.LoadKey = PackHeader.LoadKey) '
         + 'JOIN PackDetail WITH (NOLOCK) ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo) '
         + 'JOIN UCC WITH (NOLOCK) ON (PACKDETAIL.REFNO = UCC.UCCNO) '
         + 'JOIN LOC WITH (NOLOCK) ON (UCC.LOC = LOC.LOC) '
         + 'WHERE  WaveDetail.WaveKey = @c_WaveKey '--'0000037041'
   IF (@n_StartCartonNo > 0 AND @n_EndCartonNo > 0) AND (@n_EndCartonNo >= @n_StartCartonNo)
   BEGIN
      SET @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' AND PackDetail.CartonNo BETWEEN @n_StartCartonNo AND @n_EndCartonNo '
   END
   IF (dbo.fnc_RTRIM(@c_StartAisle) > '' AND dbo.fnc_RTRIM(@c_EndAisle) > '')
   BEGIN
      SET @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' AND LOC.LOCAISLE BETWEEN @c_StartAisle AND @c_EndAisle '--='04'
   END
   IF (dbo.fnc_RTRIM(@c_StartLocLevel) > '' AND dbo.fnc_RTRIM(@c_EndLocLevel) > '') 
   	AND ISNUMERIC(@c_StartLocLevel) = 1
   	AND ISNUMERIC(@c_EndLocLevel) = 1
   	AND (CAST(@c_StartLocLevel AS INT) >=CAST(@c_EndLocLevel AS INT))
   BEGIN
		SET @n_StartLocLevel = @c_StartLocLevel
		SET @n_EndLocLevel = @c_EndLocLevel
      SET @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' AND LOC.LOCLEVEL BETWEEN @n_StartLocLevel AND @n_EndLocLevel '--= 1
   END
   SET @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement)
	+ ' GROUP BY PackHeader.PickSlipNo, '
	+ ' PackHeader.LoadKey, '
	+ ' PackHeader.Route, '
	+ ' PackDetail.LabelNo, '   
	+ ' PackDetail.CartonNo, ' 
	+ ' LOC.LOC, ' 
   + ' LOC.LOCAISLE, LOC.LocLevel, LOC.LOC ' -- Added By Shong on 21th Aug 2008
	+ ' ORDER BY LOC.LOC, PackHeader.PickSlipNo, PackDetail.CartonNo'

--print @c_SQLStatement
--return

    EXEC sp_executeSql @c_SQLStatement,
    N'@c_WaveKey NVARCHAR(10), @n_StartCartonNo int, @n_EndCartonNo int, @c_StartAisle NVARCHAR(10), @c_EndAisle NVARCHAR(10), @n_StartLocLevel int, @n_EndLocLevel int', 
    @c_WaveKey, @n_StartCartonNo, @n_EndCartonNo, @c_StartAisle, @c_EndAisle, @n_StartLocLevel, @n_EndLocLevel

	DECLARE Ext_cur CURSOR FOR 
	SELECT DISTINCT Orders.ExternOrderkey, Orders.Loadkey, PackHeader.PickSlipNo
   FROM   WaveDetail WITH (NOLOCK)
          JOIN Orders WITH (NOLOCK) ON (Orders.UserDefine09 = WaveDetail.WaveKey)
          JOIN LoadplanDetail WITH (NOLOCK) ON (Orders.OrderKey = LoadplanDetail.OrderKey)
          JOIN PackHeader WITH (NOLOCK) ON (LoadplanDetail.LoadKey = PackHeader.LoadKey)-- AND LoadPlanDetail.OrderKey = PackHeader.OrderKey)
   WHERE WaveDetail.WaveKey = @c_WaveKey
	ORDER BY Orders.ExternOrderkey	
	
	OPEN Ext_cur 	

	SELECT @i_ExtCnt  = 1
	SELECT @i_LineCnt = 0

	FETCH NEXT FROM Ext_cur INTO @c_externOrderkey, @c_loadkey, @c_pickslipno

	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF @i_LineCnt = 5
		BEGIN
			SELECT @i_LineCnt = 0
			SELECT @i_ExtCnt  = @i_ExtCnt + 1
		END

		SELECT @i_LineCnt = @i_LineCnt + 1

		IF @i_ExtCnt = 20
			BREAK

		-- PRINT @c_pickslipno + ' ' + @c_Loadkey + ' ' + @c_externOrderkey
		IF @i_LineCnt = 1
		BEGIN
			SELECT @SQL = "UPDATE #RESULT SET ExtOrder" + dbo.fnc_RTRIM(dbo.fnc_LTRIM(@i_ExtCnt)) + " = N'" + dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_externOrderkey)) + "' " 						
						+ "WHERE Pickslipno = N'" + dbo.fnc_RTRIM(@c_pickslipno) + "' AND Loadkey = N'" + dbo.fnc_RTRIM(@c_Loadkey) + "'" 
		END
		ELSE		
		BEGIN
			SELECT @SQL = "UPDATE #RESULT SET ExtOrder" + dbo.fnc_RTRIM(dbo.fnc_LTRIM(@i_ExtCnt)) + " = dbo.fnc_RTRIM(dbo.fnc_LTRIM(Extorder" + dbo.fnc_RTRIM(dbo.fnc_LTRIM(@i_ExtCnt)) + ")) + ' ' + N'" + dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_externOrderkey)) + "' " 						
							+ "WHERE Pickslipno = N'" + dbo.fnc_RTRIM(@c_pickslipno) + "' AND Loadkey = N'" + dbo.fnc_RTRIM(@c_Loadkey) + "'" 
		END

	   -- PRINT @SQL
		EXEC (@SQL)

		FETCH NEXT FROM Ext_cur INTO @c_externOrderkey, @c_loadkey, @c_pickslipno
	END
	CLOSE Ext_cur
	DEALLOCATE Ext_cur

	SELECT 
      [PickSlipNo], 
      [LoadKey], 
      [Route], 
      [ConsigneeKey], 
      [DeliveryDate], 
      [C_Company], 
      [C_Address1], 
      [C_Address2], 
      [C_Address3], 
      [C_City], 
      [xDockLane], 
      [LabelNo], 
      [CartonNo], 
      [ExtOrder1], 
      [ExtOrder2], 
      [ExtOrder3], 
      [ExtOrder4], 
      [ExtOrder5], 
      [ExtOrder6], 
      [ExtOrder7], 
      [ExtOrder8], 
      [ExtOrder9], 
      [ExtOrder10], 
      [TotalSku],
      [TotalPcs], 
      [LocAisle], 
      [LocLevel], 
      [LOC]
   FROM #RESULT

 	DROP TABLE #RESULT

END

GO