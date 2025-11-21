SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/	 
/*	Function:  fnc_PackingList95														*/	 
/*	Creation	Date:	12-JAN-2021															*/	 
/*	Copyright: IDS																			*/	 
/*	Written by:	CSCHONG																	*/	 
/*																								*/	  
/*	Purpose:	WMS-16011 -	[CN] PVH_Packing list_CR								*/	 
/*																								*/	 
/*	Called By:	isp_Packing_List_95													*/	 
/*																								*/	 
/*	PVCS Version: 1.0																		*/	 
/*																								*/	 
/*	Version:	5.4																			*/	 
/*																								*/	 
/*	Data Modifications:																	*/	 
/*																								*/	 
/*	Updates:																					*/	 
/*	Date			 Author	  Ver.  Purposes											*/	 
/************************************************************************/	 
  
CREATE FUNCTION [dbo].fnc_PackingList95 (	  
						@c_orderkey	NVARCHAR(20)	
) RETURNS @RetPackList42 TABLE	
			(		Orderkey		 NVARCHAR(20)	
				,	A01			 NVARCHAR(4000)	
				,	A02			 NVARCHAR(4000)	
				,	A03			 NVARCHAR(4000)	
				,	A04			 NVARCHAR(4000)	
				,	A05			 NVARCHAR(4000)	 
				,	A06			 NVARCHAR(4000)	 
				,	A07			 NVARCHAR(4000)	 
				,	A08			 NVARCHAR(4000)	 
				,	A09			 NVARCHAR(4000)	 
				,	A10			 NVARCHAR(4000)	 
				,	A11			 NVARCHAR(4000)  
				,	A12			 NVARCHAR(4000)	
				,	A13			 NVARCHAR(4000)  
				,	A14			 NVARCHAR(4000)  
				,	A15			 NVARCHAR(4000)  
				,	A16			 NVARCHAR(4000)  
				,	A17			 NVARCHAR(4000)  
				,	A18			 NVARCHAR(4000)  
				,	A19			 NVARCHAR(4000)  
				,	A20			 NVARCHAR(4000)  
				,	A21			 NVARCHAR(4000) 
				,	A22			 NVARCHAR(4000) 
				,	A23			 NVARCHAR(4000) 
				,	A24			 NVARCHAR(4000) 
				,	A25			 NVARCHAR(4000)	 
				,	A26			 NVARCHAR(4000)  
				,	A27			 NVARCHAR(4000) 
				,	A28			 NVARCHAR(4000) 
			)												  
AS	 
BEGIN	 
	SET QUOTED_IDENTIFIER OFF	
  
	DECLARE	@c_LabelName		NVARCHAR(60)  
			,	@c_LabelValue		NVARCHAR(4000)		 
			,	@c_A01				NVARCHAR(4000)	 
			,	@c_A02				NVARCHAR(4000)	 
			,	@c_A03				NVARCHAR(4000)	 
			,	@c_A04				NVARCHAR(4000)	 
			,	@c_A05				NVARCHAR(4000)	 
			,	@c_A06				NVARCHAR(4000)	 
			,	@c_A07				NVARCHAR(4000)	 
			,	@c_A08				NVARCHAR(4000)	 
			,	@c_A09				NVARCHAR(4000)	 
			,	@c_A10				NVARCHAR(4000)	 
			,	@c_A11				NVARCHAR(4000)	 
			,	@c_A12				NVARCHAR(4000)	 
			,	@c_A13				NVARCHAR(4000)	 
			,	@c_A14				NVARCHAR(4000)	  
			,	@c_A15				NVARCHAR(4000)	
			,	@c_A16				NVARCHAR(4000)	 
			,	@c_A17				NVARCHAR(4000)	 
			,	@c_A18				NVARCHAR(4000)	 
			,	@c_A19				NVARCHAR(4000)	  
			,	@c_A20				NVARCHAR(4000)	
			,	@c_A21				NVARCHAR(4000)	
			,	@c_A22				NVARCHAR(4000)	
			,	@c_A23				NVARCHAR(4000)	
			,	@c_A24				NVARCHAR(4000)	
			,	@c_A25				NVARCHAR(4000)	  
			,	@c_A26				NVARCHAR(4000)	
			,	@c_A27				NVARCHAR(4000)		
			,	@c_A28				NVARCHAR(4000)	
  
	SET @c_LabelName = ''  
	SET @c_LabelValue= ''  
	SET @c_A01	= ''	
	SET @c_A02	= ''	  
	SET @c_A03	= ''	  
	SET @c_A04	= ''	 
	SET @c_A05	= ''	
	SET @c_A06	= ''	
	SET @c_A07	= ''	
	SET @c_A08	= ''	
	SET @c_A09	= ''	
	SET @c_A10	= ''		 
	SET @c_A11	= ''	
	SET @c_A12	= ''	  
	SET @c_A13	= ''	  
	SET @c_A14	= ''			 
	SET @c_A15	= ''	 
	SET @c_A16	= ''		 
	SET @c_A17	= ''	
	SET @c_A18	= ''		 
	SET @c_A19	= ''			 
	SET @c_A20	= ''	 
	SET @c_A21	= '' 
	SET @c_A22	= '' 
	SET @c_A23	= '' 
	SET @c_A24	= '' 
	SET @c_A25	= '' 
	SET @c_A26	= '' 
	SET @c_A27	= '' 
	SET @c_A28	= '' 
	 
  
	DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY	STATIC READ_ONLY FOR	 
	 SELECT CL.code  
			, CL.Notes	
	FROM ORDERS	OH	WITH (NOLOCK)	
	JOIN CODELKUP	  CL WITH (NOLOCK) ON (CL.ListName = 'PVHPAC')	 
												 AND CL.storerkey	= OH.storerkey	 
	  
	WHERE	OH.Orderkey	= @c_Orderkey		  
	  
	OPEN CUR_LBL  
  
	FETCH	NEXT FROM CUR_LBL	INTO @c_LabelName	 
									  ,  @c_LabelValue  
									  
		  
  
	WHILE	@@FETCH_STATUS	<>	-1	 
	BEGIN		
		SET @c_A01	=	CASE WHEN @c_LabelName = 'A01'	THEN @c_LabelValue ELSE	@c_A01	END	
		SET @c_A02	=	CASE WHEN @c_LabelName = 'A02'	THEN @c_LabelValue ELSE	@c_A02	END	
		SET @c_A03	=	CASE WHEN @c_LabelName = 'A03'	THEN @c_LabelValue ELSE	@c_A03	END  
		SET @c_A04	=	CASE WHEN @c_LabelName = 'A04'	THEN @c_LabelValue ELSE	@c_A04	END	
		SET @c_A05	=	CASE WHEN @c_LabelName = 'A05'	THEN @c_LabelValue ELSE	@c_A05	END	
		SET @c_A06	=	CASE WHEN @c_LabelName = 'A06'	THEN @c_LabelValue ELSE	@c_A06	END	
		SET @c_A07	=	CASE WHEN @c_LabelName = 'A07'	THEN @c_LabelValue ELSE	@c_A07	END	
		SET @c_A08	=	CASE WHEN @c_LabelName = 'A08'	THEN @c_LabelValue ELSE	@c_A08	END	
		SET @c_A09	=	CASE WHEN @c_LabelName = 'A09'	THEN @c_LabelValue ELSE	@c_A09	END	
		SET @c_A10	=	CASE WHEN @c_LabelName = 'A10'	THEN @c_LabelValue ELSE	@c_A10	END	
		SET @c_A11	=	CASE WHEN @c_LabelName = 'A11'	THEN @c_LabelValue ELSE	@c_A11	END	
		SET @c_A12	=	CASE WHEN @c_LabelName = 'A12'	THEN @c_LabelValue ELSE	@c_A12	END  
		SET @c_A13	=	CASE WHEN @c_LabelName = 'A13'	THEN @c_LabelValue ELSE	@c_A13	END	 
		SET @c_A14	=	CASE WHEN @c_LabelName = 'A14'	THEN @c_LabelValue ELSE	@c_A14	END  
		SET @c_A15	=	CASE WHEN @c_LabelName = 'A15'	THEN @c_LabelValue ELSE	@c_A15	END  
		SET @c_A16	=	CASE WHEN @c_LabelName = 'A16'	THEN @c_LabelValue ELSE	@c_A16	END	
		SET @c_A17	=	CASE WHEN @c_LabelName = 'A17'	THEN @c_LabelValue ELSE	@c_A17	END	
		SET @c_A18	=	CASE WHEN @c_LabelName = 'A18'	THEN @c_LabelValue ELSE	@c_A18	END	
		SET @c_A19	=	CASE WHEN @c_LabelName = 'A19'	THEN @c_LabelValue ELSE	@c_A19	END  
		SET @c_A20	=	CASE WHEN @c_LabelName = 'A20'	THEN @c_LabelValue ELSE	@c_A20	END 
		SET @c_A21	=	CASE WHEN @c_LabelName = 'A21'	THEN @c_LabelValue ELSE	@c_A21	END 
		SET @c_A22	=	CASE WHEN @c_LabelName = 'A22'	THEN @c_LabelValue ELSE	@c_A22	END 
		SET @c_A23	=	CASE WHEN @c_LabelName = 'A23'	THEN @c_LabelValue ELSE	@c_A23	END 
		SET @c_A24	=	CASE WHEN @c_LabelName = 'A24'	THEN @c_LabelValue ELSE	@c_A24	END 
		SET @c_A25	=	CASE WHEN @c_LabelName = 'A25'	THEN @c_LabelValue ELSE	@c_A25	END 
		SET @c_A26	=	CASE WHEN @c_LabelName = 'A26'	THEN @c_LabelValue ELSE	@c_A26	END 
		SET @c_A27	=	CASE WHEN @c_LabelName = 'A27'	THEN @c_LabelValue ELSE	@c_A27	END 
		SET @c_A28	=	CASE WHEN @c_LabelName = 'A28'	THEN @c_LabelValue ELSE	@c_A28	END  
	 
		  
		FETCH	NEXT FROM CUR_LBL	INTO @c_LabelName	 
										  ,  @c_LabelValue  
  
	END  
	CLOSE	CUR_LBL	
	DEALLOCATE CUR_LBL  
  
  
  
	INSERT INTO	@RetPackList42	 
	  ( Orderkey	 
			,	A01		 
			,	A02	
			,	A03  
			,	A04	 
			,	A05	 
			,	A06	 
			,	A07	 
			,	A08	 
			,	A09	 
			,	A10	 
			,	A11	 
			,	A12
			,	A13	  
			,	A14  
			,	A15	 
			,	A16	 
			,	A17
			,	A18
			,	A19  
			,	A20
			,	A21 
			,	A22
			,	A23
			,	A24
			,	A25
			,	A26
			,	A27
			,	A28	
			)	
	SELECT @c_orderkey  
			,	@c_A01	
			,	@c_A02	
			,	@c_A03  
			,	@c_A04	
			,	@c_A05  
			,	@c_A06  
			,	@c_A07  
			,	@c_A08  
			,	@c_A09  
			,	@c_A10  
			,	@c_A11  
			,	@c_A12
			,	@c_A13	 
			,	@C_A14  
			,	@c_A15 
			,	@c_A16  
			,	@c_A17  
			,	@c_A18
			,	@c_A19	
			,	@C_A20  
			,	@c_A21	
			,	@c_A22
			,	@c_A23
			,	@c_A24 
			,	@c_A25
			,	@c_A26
			,	@c_A27
			,	@c_A28 
			
  
	RETURN  
END  

GO