rs.initiate( {
	   _id : "rs0",
	   members: [
		         { _id: 0, host: "mongodb0-1:27017" },
		         { _id: 1, host: "mongodb0-2:27017" },
		         { _id: 2, host: "mongodb0-3:27017" }
		      ]
})
