SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Loading_List_rdt              			  	      */
/* Creation Date: 18-May-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS-1889 - Print Loading List ( Fn1180)                      */
/*                                                                      */
/*                                                                      */
/* Called By: report dw = r_dw_Loading_List_rdt                         */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 26-Jul-17    CheeMun   1.1   IN00415286 - Extend Pallet Field        */
/************************************************************************/

CREATE PROC [dbo].[isp_Loading_List_rdt] (
   @c_ShipmentID NVARCHAR(30)
  ,@c_TruckID    NVARCHAR(30)
  ,@c_Facility   NVARCHAR(10)  
) 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   
   DECLARE @n_rowid int,
           @n_rowcnt int
        
        
  DECLARE @c_PalletKey         NVARCHAR(30),
          @c_Gettruckid        NVARCHAR(60), 
          @c_GetShipmentID     NVARCHAR(60),
          @c_PalletKeyList     NVARCHAR(2000) ,     --IN00415286
          @c_DelimiterSign     NVARCHAR(5),
          @n_TTLPLT            INT,
          @n_LineNo            INT,
          @c_FUDEF17           NVARCHAR(30),
          @c_PLTKey            NVARCHAR(5),
          @c_Principal         NVARCHAR(15),
          @c_prev_PLTKey       NVARCHAR(5),
          @c_Prev_Principal    NVARCHAR(15),
          @c_destWhs           NVARCHAR(10),
          @n_PLTCNT            INT
        
        
		 SET @c_DelimiterSign       = ';    '
		 SET @c_PalletKeyList       = ''
		 SET @n_TTLPLT              = 0
		 SET @n_PLTCNT              = 0
		 SET @n_LineNo              = 1
		 SET @c_FUDEF17             = 11    
		 SET @c_prev_PLTKey         = ''
		 SET @c_Prev_Principal      ='' 
             
   CREATE TABLE #TEMP_LoadingList
         (  Rowid             INT IDENTITY(1,1),
         	ShipmentID        NVARCHAR(30) NULL,
        	   FromWHS           NVARCHAR(30) NULL,
      		ToWHS             NVARCHAR(30) NULL,
      		DestWHS           NVARCHAR(20) NULL, 
      		StorerKey         NVARCHAR(15) NULL,
      		PalletKey         NVARCHAR(2500) NULL,     --IN00415286
      		TruckID           NVARCHAR(30) NULL,
      		TTLPLT            int NULL 
         )
         
         
        SELECT @c_FUDEF17 = ISNULL(F.Userdefine17,'')
		  FROM Facility F WITH (NOLOCK)
		  WHERE F.facility = @c_Facility   
        
         
         DECLARE C_Verify_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
 
			SELECT DISTINCT truckid,ShipmentID,principal,ck.[Description]
			FROM OTMIDTrack WITH (NOLOCK)
			left join codelkup ck (nolock) on ck.code=substring(palletkey,3,2) and listname='PLTdecode'
			WHERE ShipmentID = @c_ShipmentID
         AND TruckID =@c_TruckID
         AND mustatus='8'
	       order by ck.description,Principal
	       
			OPEN C_Verify_Record 
			FETCH NEXT FROM C_Verify_Record INTO @c_Gettruckid
														  , @c_GetShipmentID
														 -- , @c_PLTKey
														  , @c_Principal
														  , @c_destWhs
                                      
                                      
			 WHILE (@@FETCH_STATUS <> -1) 
			 BEGIN    
			 	
			 	SET @n_PLTCNT = 1
			 	SET @c_PalletKeyList = ''
			 	 
			 	 DECLARE C_PLTKEY_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              SELECT DISTINCT PalletKey    
			     FROM OTMIDTrack WITH (NOLOCK) 
			     left join codelkup ck (nolock) on ck.code=substring(palletkey,3,2) and listname='PLTdecode'  
				  WHERE ShipmentID = @c_GetShipmentID 
				  AND TruckID =@c_Gettruckid  
				  AND principal=@c_Principal 
				  AND MUStatus = '8'
				  AND ck.[Description]= @c_destWhs 
             --AND substring(palletkey,3,2) = @c_PLTKey
             --AND palletkey = @c_PLTKey  
              ORDER BY  OTMIDTrack.PalletKey      
             
             OPEN C_PLTKEY_Record 
			    FETCH NEXT FROM C_PLTKEY_Record INTO @c_PalletKey
        
			 	  WHILE (@@FETCH_STATUS <> -1) 
			     BEGIN 
			     	 
			     	
						 SELECT @n_PLTCNT = COUNT(DISTINCT PalletKey)
						 FROM OTMIDTrack WITH (NOLOCK)
						  left join codelkup ck (nolock) on ck.code=substring(palletkey,3,2) and listname='PLTdecode'
						 WHERE ShipmentID = @c_GetShipmentID
						 AND TruckID =@c_Gettruckid
						 AND principal=@c_Principal
						 AND MUStatus = '8'
                   AND ck.[Description]=@c_destWhs
						 --AND palletkey = @c_PLTKey    
						 
						  SET @n_LineNo = 1
						 --SELECT @n_TTLPLT AS '@n_TTLPLT' ,@c_Principal AS '@c_Principal'               
     
					  IF (@n_LineNo = @n_PLTCNT)
					  BEGIN
     					   SET @c_DelimiterSign = ''
					  END
                 ELSE
                 BEGIN
                     SET @c_DelimiterSign = ';    '
                 END

					  SET @c_PalletKeyList = CASE WHEN @c_PalletKeyList = '' THEN @c_PalletKey  + @c_DelimiterSign --(@c_PLTKey+@c_Principal+@c_PalletKey)  + @c_DelimiterSign 
													 ELSE @c_PalletKeyList +  @c_PalletKey + @c_DelimiterSign END 
											 
					SET @n_LineNo = @n_LineNo + 1  								 
											 
			 FETCH NEXT FROM C_PLTKEY_Record INTO  @c_PalletKey 
                                                                   
			 END       
			  
    
			  CLOSE C_PLTKEY_Record
			  DEALLOCATE C_PLTKEY_Record								 
			 
					
     					 INSERT INTO #TEMP_LoadingList (ShipmentID,
        													FromWHS,
      													ToWHS,
      													DestWHS, 
      													StorerKey,
      													PalletKey,
      													TruckID  ,
      													TTLPLT )
							 SELECT DISTINCT OIDT.ShipmentID,@c_FUDEF17,ISNULL(c.[Description],''),ISNULL(c1.[Description],''),--substring(OIDT.PalletKey,3,2),
							 OIDT.Principal,@c_PalletKeyList,OIDT.TruckID,1
							 FROM OTMIDTrack AS OIDT WITH (NOLOCK)
							 LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.Code=OIDT.LocationName AND c.LISTNAME='PLTDECODE'
							 LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Code=substring(OIDT.PalletKey,3,2) AND c1.LISTNAME='PLTDECODE'
							 WHERE ShipmentID = @c_GetShipmentID
							 AND TruckID =@c_Gettruckid
							 AND OIDT.Principal=@c_Principal
							 AND MUstatus='8'
							 AND c1.[Description]= @c_destWhs
							 --AND palletkey =  @c_PLTKey
							 ORDER BY OIDT.ShipmentID   
					  
                            
			                   
			 FETCH NEXT FROM C_Verify_Record INTO  @c_Gettruckid
															  , @c_GetShipmentID 
															--  , @c_PLTKey
															  , @c_Principal  
															  , @c_destWhs
                                                                   
			 END       
			  
    
			  CLOSE C_Verify_Record
			  DEALLOCATE C_Verify_Record     
   
         
          SET @n_TTLPLT = 1
          
			 SELECT @n_TTLPLT = COUNT (DISTINCT palletkey) 
			 FROM otmidtrack o (NOLOCK)
			 left join codelkup ck (NOLOCK) on ck.code=substring(palletkey,3,2) and listname='PLTdecode'
			 where truckid=@c_truckid
			 and mustatus='8'
			 and shipmentid=@c_ShipmentID
			 
			 
			 UPDATE #TEMP_LoadingList
			 SET TTLPLT = @n_TTLPLT
			 WHERE truckid=@c_truckid
			 AND shipmentid=@c_ShipmentID


			SELECT * FROM #TEMP_LoadingList
			ORDER BY ShipmentID,ToWHS

END

GO