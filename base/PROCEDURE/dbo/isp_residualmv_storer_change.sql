SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_RESIDUALMV_Storer_Change                        */
/* Creation Date:  2012-02-15                                            */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: Change FNPC StorerKey to Pacific Alliance StorerKey          */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: N/A                                                     */
/*                                                                       */
/* Version: 1.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author    Ver.  Purposes                                 */
/*																		 */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_RESIDUALMV_Storer_Change]

	@c_NewStorerKey NVARCHAR(10)  
	, @c_MessageType NVARCHAR(15)

AS


/********************************************/
/*	Drop Temp Table (If They Exist)			*/
/********************************************/
IF OBJECT_ID(N'tempdb..#t_TCP_INLOG') IS NOT NULL
DROP TABLE #t_TCP_INLOG



/********************************************/
/*	Get TCP Data To Process					*/
/********************************************/
SELECT SERIALNO, DATA, MESSAGENUM INTO #t_TCP_INLOG FROM IDSUS.dbo.TCPSOCKET_INLOG(NOLOCK) WHERE ISNULL(RTRIM(SUBSTRING(DATA,1,15)),'') = @c_MessageType AND [STATUS] = '5' 
AND ADDDATE >= CONVERT(VARCHAR(10), GETDATE()-3,101)
ORDER BY ADDDATE DESC


SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
   
DECLARE
	@c_SerialNo NVARCHAR(10)
	, @c_MsgNumber NVARCHAR(8)
	, @c_Data NVARCHAR(MAX)
	, @c_MsgStorerKey NVARCHAR(10)
	, @c_Sku NVARCHAR(18)
	, @c_SkuCount INT
	, @r_Count INT
	, @b_Count INT
	, @c_ErrMsg NVARCHAR(250)
	, @c_Continue INT
	
	SET @b_Count = 0
	--SET @c_NewStorerKey = '22000903'
	
	SELECT @r_Count = COUNT(*) FROM #t_TCP_INLOG(NOLOCK) 	

	DECLARE CUR_TCP_GET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
		SELECT SERIALNO, DATA FROM #t_TCP_INLOG(NOLOCK)
			
	OPEN CUR_TCP_GET

	WHILE @b_Count <= @r_Count
		BEGIN
			/*	Set Default Values to Variables	*/
			SET @c_Continue = 0
		
			/*	Get SKU, StorerKey & MsgNumber from Message	*/
			SET @c_Sku = ISNULL(RTRIM(SUBSTRING(@c_Data,44,20)), '')
			SET @c_MsgStorerKey = ISNULL(RTRIM(SUBSTRING(@c_Data,24,15)), '')
			SET @c_MsgNumber = ISNULL(RTRIM(SUBSTRING(@c_Data,16,8)), '')
			
			/*	Protect against NULL values	*/
			IF @c_Sku = ''
				BEGIN
					SET @c_ErrMsg = 'SKU is missing from message'
					SET @c_Continue = 1
				END
				
			IF @c_MsgStorerKey = ''
				BEGIN				
					SET @c_ErrMsg = 'StoreKey missing from message'
					SET @c_Continue = 1
				END	
			
			IF @c_MsgNumber = ''
				BEGIN
					SET @c_ErrMsg = 'Missing Message Number'
					SET @c_Continue = 1
				END	
			
			IF @c_Continue = 0
				BEGIN
					/*	Check SKU count	*/
					SELECT @c_SkuCount = COUNT(*) FROM SKU(NOLOCK) WHERE SKU = @c_Sku

					/*	If SKU Count > 1 Create Log	*/
					IF @c_SkuCount > 1
						BEGIN
							
							/*	First Create Log*/
							INSERT INTO jam_tcp_log SELECT @c_SerialNo, @c_Sku, @c_SkuCount, @c_MsgNumber, @c_Data							
							
							/*	Check to see if SKU is for FNPC StorerKey*/
							IF EXISTS(SELECT 1 FROM SKU(NOLOCK) WHERE SKU = @c_Sku AND STORERKEY = @c_MsgStorerKey)
								BEGIN
									SET @c_ErrMsg = 'SKU exist for FNCP StorerKey'
									SET @c_Continue = 1
								END
								
							/*	Check to see if the SKU exist for Redlands StorerKey*/
							IF @c_Continue = 0
								BEGIN
									IF EXISTS(SELECT 1 FROM SKU(NOLOCK) WHERE SKU = @c_Sku AND STORERKEY = @c_NewStorerKey)
										BEGIN
											/*	Create Record Backup Before Update	*/
											INSERT INTO jam_tcpsocket_bkup SELECT 'O', * FROM IDSUS.dbo.TCPSOCKET_INLOG
																		   WHERE SERIALNO = @c_SerialNo
										
											/*	Update Record	*/
											UPDATE IDSUS.dbo.TCPSOCKET_INLOG
												SET DATA = REPLACE(DATA, @c_MsgStorerKey, @c_NewStorerKey)
													, [STATUS] = '0'
													--, NoOfTry = '0'									
											WHERE SERIALNO = @c_SerialNo
											
											/*	Create Log Record After Update	*/
											INSERT INTO jam_tcpsocket_bkup SELECT 'U', * FROM IDSUS.dbo.TCPSOCKET_INLOG
																		   WHERE SERIALNO = @c_SerialNo
										END								
								END	
						END
					
					IF @c_Continue = 0
						BEGIN
							IF @c_SkuCount = 1
								BEGIN
									IF EXISTS (SELECT 1 FROM SKU(NOLOCK) WHERE SKU = @c_Sku AND STORERKEY = @c_NewStorerKey)
										BEGIN
											/*	Create Record Backup Before Update	*/
											INSERT INTO jam_tcpsocket_bkup SELECT 'O', * FROM IDSUS.dbo.TCPSOCKET_INLOG
																		   WHERE SERIALNO = @c_SerialNo
										
											/*	Update Record	*/
											UPDATE IDSUS.dbo.TCPSOCKET_INLOG
												SET DATA = REPLACE(DATA, @c_MsgStorerKey, @c_NewStorerKey)
													, [STATUS] = '0'
													--, NoOfTry = '0'									
											WHERE SERIALNO = @c_SerialNo
											
											/*	Create Log Record After Update	*/
											INSERT INTO jam_tcpsocket_bkup SELECT 'U', * FROM IDSUS.dbo.TCPSOCKET_INLOG
																		   WHERE SERIALNO = @c_SerialNo
												
										END				
								END	
						END
								
				END
						
			FETCH NEXT FROM CUR_TCP_GET INTO @c_SerialNo, @c_Data

			
			SET @b_Count = @b_Count + 1
			SET @c_SkuCount = 0

		END
		
	CLOSE CUR_TCP_GET
	DEALLOCATE CUR_TCP_GET

GO